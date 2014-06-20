# encoding: UTF-8

require './lib/config'
require 'elasticsearch'
require 'hashie'

module TwitterLinks

    class Index

        # Init ElasticSearch
        def initialize **params
            config = TwitterLinks::Config.get
            @@index = config['elastic_search_index']
            @@debug = config['elastic_search_debug']

            params = {log: @@debug}.merge(params)
            @client = Elasticsearch::Client.new params
        end

        # Get a document
        def get **params
            params = {index: @@index}.merge(params)
            r = @client.get params
            Hashie::Mash.new r
        end

        # Search documents
        def search **params
            params = {index: @@index}.merge(params)
            r = @client.search params
            Hashie::Mash.new r
        end

        # Count documents
        def count **params
            params = {index: @@index}.merge(params)
            r = @client.count params
            r['count']
        end

        # Add a document
        def index **params
            params = {index: @@index}.merge(params)
            r = @client.index params
            Hashie::Mash.new r
        end

        # Delete a list of documents
        def delete_by_query **params
            params = {index: @@index}.merge(params)
            @client.delete_by_query params
        end

        # Commit last additions/deletions
        def refresh
            @client.indices.refresh
        end

    end

end
