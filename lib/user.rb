# encoding: UTF-8

require './lib/abstract'
require './lib/link'

module TwitterLinks

    class User < Abstract

        self.type = 'user'
        self.attributes = [:screen_name, :token, :secret, :crawled_at]

        # Init a user
        # Overrided to handle internal hash/array
        #
        # Params:
        #   +id+:: User ID
        #   +data+:: User data
        def initialize id, data = {}
            super id, data
            @twitter = nil

            if @data['since_id'].nil? then
                @data['since_id'] = {}
            else
                @data['since_id'] = @data['since_id'].to_h
            end

            if not @data['lists'].nil? then
                @data['lists'] = @data['lists'].to_h
            end
        end

        # Save a user
        # Overrided to force commit!
        #
        # Returns true is successfully saved
        def save
            super.save
            @@elasticsearch.refresh
        end

        # Get user's links
        #
        # Params:
        #   +q+:: Query to filter links
        #   +from+:: Offset
        #   +size+:: Limit
        #   +sort+:: Order by?
        #
        # Returns an array of Link
        def links q = '*', from = 0, size = 50, sort = 'popularity:desc,date:desc'
            Link.get_all query(q), from, size, sort
        end

        # Count user's links
        #
        # Params:
        #   +q+:: Query to filter links
        #
        # Returns the number of links
        def count_links q = '*'
            Link.count query(q)
        end

        # Remove old links
        #
        # Params:
        #   +hours+:: How many hours to keep
        def clean_old_links hours = 24
            Link.delete_by_query query('date:[1 TO ' + (Time.now.to_i - (hours*3600)).to_s + ']')
        end

        # Get user's links
        #
        # Returns an array of lists
        def lists
            if @data['lists'].nil? then
                @data['lists'] = twitter.lists
                save
            end

            @data['lists']
        end

        # Get tweets
        #
        # Params:
        #   +list+:: Twitter list or home timeline
        #   +count+:: Pack requests
        #
        # Returns an array of tweets
        def tweets list, count = 10 # 100
            slug = list['slug']
            id = list['id']


            if @data.has_key? 'since_id' and @data['since_id'].has_key? id.to_s then
                since = @data['since_id'][id.to_s]
            else
                since = nil
            end

            result = twitter.tweets list, since, count

            if not result.empty? then
                @data['since_id'][id] = result.first.id
            end

            result
        end

        # Get Twitter
        #
        # Returns Twitter authenticated as current user
        def twitter
            require './lib/twitter'

            if @twitter.nil? then
                @twitter = TwitterLinks::Twitter.new(token, secret)
            end

            @twitter
        end

        #private

        # Restrict a query to current user
        #
        # Params:
        #   +q+: The initial query
        #
        # Returns the query restrict to current context
        def query q
            q + ' AND user_id:' + id
        end

    end

end
