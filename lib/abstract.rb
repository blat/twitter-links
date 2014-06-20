# encoding: UTF-8

require './lib/elasticsearch'

module TwitterLinks

    class Abstract

        @@elasticsearch = TwitterLinks::Index.new
        attr_accessor :id

        # Init
        def initialize id, data = {}
            @id = id
            @data = data
        end

        # Get one
        def self.get id
            begin
                r = @@elasticsearch.get type: self.type, id: id

                o = self.new r._id, r._source.to_h
            rescue Exception => e
                puts e.message
            end
        end

        # Get all
        def self.get_all query = '*:*', from = 0, size = 50, sort = ''
            r = @@elasticsearch.search type: self.type, q: query, from: from, size: size, sort: sort

            o = []
            r.hits.hits.each do |hit|
                o << self.new(hit._id, hit._source.to_h)
            end

            o
        end

        # Count
        def self.count query = '*:*'
            @@elasticsearch.count type: self.type, body: { query: { query_string: { query: query } } }
        end

        # Save
        def save
            @@elasticsearch.index type: self.class.type, id: @id, body: @data
        end

        # Delete
        def self.delete_by_query query
            @@elasticsearch.delete_by_query type: self.type, q: query
        end

        # Get type
        def self.type
            @type
        end

        # Set type
        def self.type= t
            @type = t
        end

        # Set attributes
        def self.attributes= a
            a.each do |attr|
                self.class_eval("def #{attr}; @data['#{attr}']; end")
                self.class_eval("def #{attr}=(val); @data['#{attr}']=val; end")
            end
        end

    end

end
