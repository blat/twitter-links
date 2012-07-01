# encoding: UTF-8

require 'redis'
require 'digest/sha1'
require 'open-uri'
require 'readability'
require 'twitter_oauth'
require 'yaml'

module TwitterRss

    class Twitter < TwitterOAuth::Client

        def initialize token = '', secret = ''
            config = YAML.load_file 'config.yml'
            options = {
                :consumer_key => config['consumer_key'],
                :consumer_secret => config['consumer_secret'],
                :token => token,
                :secret => secret
            }
            super options
        end

    end

    class MyRedis

        @@redis = Redis.new

        def initialize id
            self.id = id
        end

        def id
            @id
        end

        def id= value
            @id = value
        end

        def delete
            puts "REDIS -> del " + key
            @@redis.del key
        end

        protected

        def key
            self.class.key id
        end

        def self.key id
            table + ':' + id.to_s
        end

        def self.table
            self.name
                .gsub(/.*::/, '')
                .gsub(/[A-Z]/) { |s| '_' + s.downcase }
                .gsub(/^_/, '')
                .gsub(/s$/, '')
        end

    end

    class RedisHash < MyRedis

        def initialize id
            @data = {}
            super id
        end

        def method_missing k, v = nil
            k = k.to_s.gsub(/=/, '')

            if not v.nil? then
                @data[k] = v
                if not id.nil? then
                    puts "REDIS -> hset " + key + " " + k + " " + v.to_s.gsub(/\n/, '').slice(0, 100)
                    @@redis.hset key, k, v.to_s.force_encoding('UTF-8')
                end
            else
                if @data[k].nil? then
                    puts "REDIS -> hget " + key + " " + k
                    v = @@redis.hget key, k
                    if not v.nil? then
                        @data[k] = v.to_s.force_encoding('UTF-8')
                    end
                end
                @data[k]
            end
        end

        def self.get_all
            results = []
            pattern = table + ':*'
            puts "REDIS -> keys " + pattern
            @@redis.keys(pattern).each do |id|
                id = id.gsub(/.*:/, '')
                results << self.new(id)
            end
            results
        end

    end

    class RedisSortedSet < MyRedis

        def add value, score
            puts "REDIS -> zadd " + key + " " + score.to_s + " " + value
            @@redis.zadd key, score, value
        end

        def get start, stop
            puts "REDIS -> zrange " + key + " " + start.to_s + " " + stop.to_s
            @@redis.zrevrange key, start, stop
        end

    end

    class RedisList < MyRedis

        def get
            puts "REDIS -> smembers " + key
            @@redis.smembers key
        end

        def add value
            puts "REDIS -> sadd " + key + " " + value
            @@redis.sadd key, value
        end

    end

    class User < RedisHash

        def initialize id
            super id
            @timeline = Timeline.new self
            @twitter = Twitter.new self.token, self.secret

            if self.feed_token.nil? then
                reset_feed_token
            end
        end

        def timeline
            @timeline
        end

        def twitter
            @twitter
        end

        def crawled_at
            Time.at super.to_i
        end

        def tweets count = 200
            options = {
                :count => count,
                :include_rts => true,
                :include_entities => true,
                :exclude_replies => false
            }
            options[:since_id] = since_id if not since_id.nil?
            @twitter.friends_timeline options
        end

        def reset_feed_token
            self.feed_token = Digest::SHA1.hexdigest(self.id + (Random.rand()*Time.now.to_i).to_s)
        end

    end

    class Link < RedisHash

        def initialize id
            super id
            @link_images = Images.new self.id
            @link_tags = Tags.new self.id
            resolve
        end

        def id= value
            if not value.match(/:\/\//).nil? then
                tmp = value
                value = Digest::SHA1.hexdigest value
            end
            super value
            if not tmp.nil? then
                self.url = tmp
            end
            @link_images = Images.new value
            @link_tags = Tags.new value
        end

        def images
            @link_images.get
        end

        def images= images
            images.each do |image|
                @link_images.add image
            end
        end

        def tags
            @link_tags.get
        end

        def tags= tags
            tags.each do |tag|
                @link_tags.add tag
            end
        end

        def date
            @date
        end

        def content
            if is_image then
                result = '<a href="' + self.url + '" target="_blank"><img src="' + self.url + '" /></a>'
            elsif is_html then
                result = super + '<ul class="thumbnails">'
                self.images.each do |image|
                    result += '<li><a class="thumbnail" href="' + self.url + '" target="_blank"><img style="max-width: 200px; max-height: 100px;" src="' + image + '" /></a></li>'
                end
                result += '</ul>'
            elsif is_error then
                result = self.error
            else
                result = ''
            end
            result
        end

        def title
            result = super
            if result.nil? or result.empty? then
                result = self.url
            end
            result
        end

        def date= value
            @date = value
        end

        def summary lenght = 500
            result = content
            if not is_image then
                begin
                    result = result.gsub(/<\/?[^>]*>/, '').slice(0,lenght) + "..."
                rescue Exception => e
                    result = e.message
                    result += content.encoding.name
                end
            else
                result = '<a href="' + self.url + '" target="_blank"><img style="max-width: 500px; max-height: 250px;" src="' + self.url + '" /></a>'
            end
            result
        end

        def favicon
            "http://www.google.com/s2/favicons?domain=" + URI(url).host
        end

        private

        def is_image
            not self.type.nil? and not self.type.match(/image/).nil?
        end

        def is_html
            self.type == 'text/html'
        end

        def is_error
            not self.error.nil? and not self.error.empty?
        end

        def resolve
            if not self.url.nil? and self.error.nil? then
                puts "OPEN -> " + url

                begin
                    source = open url
                rescue Exception => e
                    puts "ERROR -> " + e.message
                    self.url = url
                    self.error = e.message
                    return
                end

                self.id = source.base_uri.to_s
                self.type = source.content_type

                if source.content_type == 'text/html' then
                    options = {
                        :tags => %w[div p img a],
                        :attributes => %w[src href],
                        :remove_empty_nodes => false
                    }

                    html = source.read

                    begin
                        # fix encoding
                        html = html.force_encoding('UTF-8')

                        # fix relative urls
                        html = html.gsub(/=('|")\//, '=\1*/')
                            .gsub(/\*\//, self.url.match(/(http|https):\/\/[\w.]+/)[0] + '/')
                    rescue Exception => e
                        puts "ERROR -> " + e.message
                    end

                    doc = Readability::Document.new(html, options)

                    self.content = doc.content
                    self.title = doc.title
                    self.images = doc.images
                end

                self.error = ''
            end
        end

    end

    class Tags < RedisList

    end

    class Images < RedisList

    end

    class Timeline < RedisSortedSet

        def initialize user
            super user.id
            @user = user
        end

        def add link, datetime
            super link.id, datetime.to_i
        end

        def get start = 0, stop = 10
            links = []
            super(start, stop).each do |link_id|
                link = Link.new(link_id)
                puts "REDIS -> zcore " + key + " " + link_id
                score = @@redis.zscore key, link_id
                link.date = Time.at score.to_i
                links << link
            end
            links
        end

        def length
            min = 0
            max = @user.crawled_at.to_i
            puts "REDIS -> zcount " + key + " " + min.to_s + " " + max.to_s
            @@redis.zcount key, min, max
        end

    end

end
