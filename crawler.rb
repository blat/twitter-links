# encoding: UTF-8

require './twitter-links'
require 'open-uri'
require './open_uri'
require 'readability'

TwitterLinks::User.get_all.each do |user|
    begin

        tweets = user.tweets
        tweets.each do |tweet|

            links = {}
            tags = []

            tags << '@' + tweet['user']['screen_name']

            tweet['entities'].each do |type, entities|
                entities.each do |entity|

                    case type

                    when 'urls'
                        id = entity['url']
                        id = id[12, id.length]
                        links[id] = {
                            'url' => entity['expanded_url'],
                            'title' => entity['display_url']
                        }

                    when 'user_mentions'
#                        tags << '@' + entity['screen_name']

                    when 'hashtags'
                        tags << '#' + entity['text']

                    when 'media'
                        id = entity['url']
                        id = id[12, id.length]
                        links[id] = {
                            'url' => entity['media_url'],
                            'title' => entity['display_url']
                        }

                    else
                        puts "UNKNOWN TYPE: " + type
                        puts entity
                    end
                end
            end

            links.each do |id, data|

                link = TwitterLinks::Link.new(id, data)
                link.set 'date', Time.parse(tweet['created_at']).to_i

                tags.uniq.each do |tag|
                    link.add_tag tag
                end

                begin

                    url = link.get 'url'
                    #printf "OPEN -> %s\n", uri
                    source = open url, :allow_redirections => :all

                    # save final link
                    link.set 'url', source.base_uri.to_s

                    # add host as tag
                    host = source.base_uri.host.downcase
                    host = host.start_with?('www.') ? host[4..-1] : host
                    link.add_tag host

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

                            # fix relative links
                            html = html.gsub(/=('|")\//, '=\1*/')
                                .gsub(/\*\//, url.match(/(http|https):\/\/[\w.]+/)[0] + '/')
                        rescue Exception => e
                            printf "ERROR -> %s\n", e.message
                        end

                        doc = Readability::Document.new(html, options)

                        link.set 'title', doc.title.to_s.strip
                        link.set 'content', doc.content.to_s.strip

                    else
                        # add content type as tag
                        link.add_tag source.content_type
                    end

                rescue Exception => e
                    printf "ERROR -> %s\n", e.message
                end

                link.save

                user.add_link link
            end

        end

        if not tweets.empty? then
            user.set 'since_id', tweets.first['id']
        end
        user.set 'crawled_at', Time.now.to_i
        user.save

    rescue Exception => e
        puts e.message
    end
end
