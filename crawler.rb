# encoding: UTF-8

require './twitter-rss'

TwitterRss::User.get_all.each do |user|
    begin

        tweets = user.tweets
        tweets.each do |tweet|

            tweet['entities']['urls'].each do |entity|
                if not entity['expanded_url'].nil? then

                    link = TwitterRss::Link.new entity['expanded_url']

                    tags = []
                    tweet['entities']['hashtags'].each do |tag|
                        tags << tag['text']
                    end
                    link.tags = tags

#            users = []
#            tweet['entities']['user_mentions'].each do |mention|
#                users.push mention['screen_name']
#            end
#            users.push tweet['user']['screen_name']

                    user.timeline.add link, Time.parse(tweet['created_at'])
                end
            end

        end

        user.since_id = tweets.first['id'] if not tweets.empty?
        user.crawled_at = Time.now.to_i

    rescue Exception => e
        puts e.message
    end
end
