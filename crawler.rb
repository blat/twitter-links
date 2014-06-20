# encoding: UTF-8

require './lib/link'
require './lib/user'

TwitterLinks::User.get_all.each do |user|

    user.lists.values.each do |list|
        user.tweets(list).each do |tweet|

            tweet.uris.each do |uri|
                TwitterLinks::Link.add_or_update uri.expanded_url, user, tweet, list
            end

            tweet.media.each do |media|
                TwitterLinks::Link.add_or_update media.media_url, user, tweet, list
            end

        end
    end

    user.crawled_at = Time.now.to_i
    user.save

    user.clean_old_links
end
