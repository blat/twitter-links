# encoding: UTF-8

require 'yaml'

module TwitterLinks

    class Config

        def self.get
            YAML.load_file 'config.yml'
        end

    end

end
