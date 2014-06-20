# encoding: UTF-8

require './lib/abstract'
require './lib/user'
require './lib/config'
require 'open-uri'
require 'json'
require 'digest/sha1'

module TwitterLinks

    class Link < Abstract

        self.type = 'link'
        self.attributes = [:user_id, :url, :title, :date, :content, :thumbnail, :domain, :popularity]

        # Init a link
        # Overrided to handle internal array/hash
        #
        # Params:
        #   +id+:: Link's ID
        #   +data+:: Link's data
        def initialize id, data = {}
            super id, data

            if @data['tweet'].nil? then
                @data['tweet'] = {}
            else
                @data['tweet'] = @data['tweet'].to_h
            end

            ['user', 'tag', 'list'].each do |a|
                if @data[a].nil? then
                    @data[a] = []
                else
                    @data[a] = @data[a].to_a
                end
            end
        end

        # Get all tweets
        #
        # Returns a hash of tweets
        def tweets
            @data['tweet']
        end

        # Get all tags
        #
        # Returns a array of tags
        def tags
            @data['tags']
        end

        # Get all lists
        #
        # Returns a array of lists
        def lists
            @data['list']
        end

        # Add or update a link
        #
        # Params:
        #   +url+:: The URL
        #   +user+:: The owner
        #   +tweet+:: The original tweet
        #   +list+:: The original list
        def self.add_or_update url, user, tweet, list
            begin
                data = self.readability url

                if data.has_key? 'url' then
                    url = data['url']
                end

                id = user.id + ':' + Digest::SHA1.hexdigest(url)

                link = self.get id
                if link.nil? then
                    link = self.new id
                    link.url = url
                    link.user_id = user.id
                end

                if data.has_key? 'title' then
                    link.title = data['title']
                end

                if data.has_key? 'content' then
                    link.content = data['content']
                end

                if data.has_key? 'lead_image_url' then
                    link.thumbnail = data['lead_image_url']
                end

                if data.has_key? 'domain' then
                    link.domain = data['domain']
                end

                link.popularity = self.popularity url
                link.date = tweet.created_at.to_i
                link.add_list list['slug']
                link.add_tweet tweet
                link.save
            rescue Exception => e
                printf "ERROR -> %s\n", e.message
            end
        end

        #private

        # Add to a list
        #
        # Params:
        #   +list+: The list
        def add_list list
            if not @data['list'].include? list then
                @data['list'] << list
            end
        end

        # Add a tweet (+ user + tags)
        #
        # Params:
        #   +tweet+: The tweet
        def add_tweet tweet
            id = tweet.id
            user = tweet.user.screen_name

            if not @data['tweet'].has_key? id then
                @data['tweet'][id] = {
                    'text' => tweet.text,
                    'user' => user
                }
            end

            add_tags tweet.hashtags
            add_user user

        end

        # Add a list of tags
        #
        # Params:
        #   +tags+: The list of tags
        def add_tags tags
            tags.each do |tag|
                if not @data['tag'].include? tag then
                    @data['tag'] << tag
                end
            end
        end

        # Add a user
        #
        # Params:
        #   +user+: The user
        def add_user user
            if not @data['user'].include? user then
                @data['user'] << user
            end
        end

        # Get more info about an URL
        #
        # Params:
        #   +url+:: The URL
        #
        # Returns a hash
        def self.readability url
            config = TwitterLinks::Config.get
            source = open('https://www.readability.com/api/content/v1/parser?token=' + config['readability_api_key'] + '&url=' + url)
            JSON.parse source.read
        end

        # Get URL popularity
        #
        # Params:
        #   +url+:: The URL
        #
        # Returns number of tweet
        def self.popularity url
            source = open('http://urls.api.twitter.com/1/urls/count.json?url=' + url)
            stats = JSON.parse source.read
            stats['count']
        end

    end

end
