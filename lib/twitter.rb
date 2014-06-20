# encoding: UTF-8

require 'twitter'
require './lib/config'

module TwitterLinks

    class Twitter

        def initialize token = '', secret = ''
            c = TwitterLinks::Config.get
            @twitter = ::Twitter::REST::Client.new do |config|
                config.consumer_key        = c['twitter_consumer_key']
                config.consumer_secret     = c['twitter_consumer_secret']
                config.access_token        = token
                config.access_token_secret = secret
            end
        end

        def lists
            begin
                result = {}
                result['home'] = {
                    'name' => 'Home',
                    'slug' => 'home',
                    'id' => 0
                }

                @twitter.lists.each do |list|
                    list = list.to_h
                    result[list[:slug]] = list
                end

            rescue Exception => e
                printf "ERROR -> %s\"", e.message
                result = []
            end

            result
        end

        # Get tweets
        #
        # Params:
        #   +list+:: Twitter list or home timeline
        #   +since+:: Last parsed tweet
        #   +count+:: Pack requests
        #
        # Returns an array of tweets
        def tweets list, since = nil, count = 10
            begin
                slug = list['slug']
                id = list['id']

                options = {
                    :count => count,
                    :include_rts => true,
                    :include_entities => true,
                    :exclude_replies => false
                }

                if not since.nil? then
                    options[:since_id] = since
                end

                result = []

                while true do
                    if slug == 'home' then
                        tweets = @twitter.home_timeline options
                    else
                        tweets = @twitter.list_timeline id, options
                    end

                    tweets.each do |tweet|
                        result << tweet
                    end

                    if tweets.length < count then
                        break
                    end

                    options[:max_id] = tweets.last.id - 1

                    break # remove
                end

            rescue Exception => e
                printf "ERROR -> %s\n", e.message
                result = []
            end
            result
        end

    end

end
