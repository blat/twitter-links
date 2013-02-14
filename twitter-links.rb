# encoding: UTF-8

require 'redis'
require 'twitter_oauth'
require 'yaml'

module TwitterLinks

    class Abstract
        @@redis = Redis.new

        def initialize id, data = []
            @id = id

            #printf "REDIS -> HGETALL %s\n", self.key
            @data = @@redis.hgetall self.key

            data.each do |key, value|
                @data[key] = value
            end
        end

        def id
            @id
        end

        def get key
            @data[key]
        end

        def set key, value
            @data[key] = value
        end

        def has? key
            @data.has_key? key
        end

        def save
            @data.each do |member, value|
                #printf "REDIS -> HSET %s %s %s\n", self.key, member, value
                @@redis.hset self.key, member, value
            end
        end

        def self.get_all
            results = []
            pattern = self.namespace + ':*'
            #printf "REDIS -> KEYS %s\n", pattern
            keys = @@redis.keys pattern

            result = []
            keys.each do |key|
                id = key.gsub(/.*:/, '')
                result << self.new(id)
            end

            result
        end

        protected

        def key
            self.class.namespace + ':' + @id.to_s
        end

        def self.namespace
            self.name
                .gsub(/.*::/, '')
                .gsub(/[A-Z]/) { |s| '_' + s.downcase }
                .gsub(/^_/, '')
        end

    end

    class Link < Abstract

        def add_tag tag
            tag = tag.downcase

            key = 'tag:' + tag + ':links'
            #printf "REDIS -> ZADD %s %s %s\n", key, self.get('date'), self.id
            @@redis.zadd key, self.get('date'), self.id

            key = 'tags:' + self.key
            #printf "REDIS -> SADD %s %s\n", key, tag
            @@redis.sadd key, tag
        end

        def get_tags
            key = 'tags:' + self.key
            #printf "REDIS -> SMEMBERS %s\n", key
            tags = @@redis.smembers key

            tags.sort do |tag1, tag2|
                if (tag1.start_with? '#' and tag2.start_with? '#') or (tag1.start_with? '@' and tag2.start_with? '@') then
                    result = tag1 <=> tag2
                else
                    if tag1.start_with? '@' then
                        result = -1
                    elsif tag2.start_with? '@' then
                        result = 1
                    elsif tag1.start_with? '#' then
                        result = -1
                    elsif tag2.start_with? '#' then
                        result = 1
                    elsif tag1.include? '/' then
                        result = 1
                    elsif tag2.include? '/' then
                        result = -1
                    else
                        result = tag1 <=> tag2
                    end
                end
                result
            end
        end

        def is_image?
            self.get_tags.each do |tag|
                if tag.start_with? 'image/' then
                    return true
                end
            end
            false
        end

        def is_html?
            self.get_tags.each do |tag|
                if tag.include? '/' then
                    return false
                end
            end
            true
        end

    end

    class User < Abstract

        def initialize id, data = []
            super id, data
            @twitter = Twitter.new get('token'), get('secret')
        end

        def twitter
            @twitter
        end

        def to_s
            '@' + @data['screen_name']
        end

        def tweets count = 100
            options = {
                :count => count,
                :include_rts => true,
                :include_entities => true,
                :exclude_replies => false
            }
            if self.has? 'since_id' then
                options[:since_id] = self.get('since_id')
            end

            result = []
            while true do
                tweets = @twitter.friends_timeline options

                tweets.each do |tweet|
                    result << tweet
                end

                if tweets.length < count then
                    break
                end

                options[:max_id] = tweets.last['id'] - 1
            end
            result
        end

        def add_link link
            key = 'links:' + self.key
            #printf "REDIS -> ZADD %s %s %s\n", key, link.get('date'), link.id
            @@redis.zadd key, link.get('date'), link.id
        end

        def get_links tag = '', start = 0, stop = 50
            key = self.filter_links tag

            #printf "REDIS -> ZREVANGE %s %s %s\n", key, start, stop
            members = @@redis.zrevrange key, start, stop

            result = []
            members.each do |member|
                result << Link.new(member)
            end

            result
        end

        def count_links tag
            key = self.filter_links tag

            #printf "REDIS -> ZCARD %s\n", key
            @@redis.zcard key
        end

        protected

        def filter_links tags
            key = 'links:' + self.key

            if not tags.empty? then
                keys = [key]
                tags.split.each do |tag|
                    keys << 'tag:' + tag + ':links'
                end
                key = Time.now.to_f.to_s

                #printf "REDIS -> ZINTERSTORE %s 2 %s\n", key, keys.join(' ')
                @@redis.zinterstore key, keys

                #printf "REDIS -> PEXPIRE %s 200\n", key
                @@redis.pexpire key, 200
            end

            key
        end
    end

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

end
