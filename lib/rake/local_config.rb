require 'yaml'

module Rake

  class LocalConfig

    attr_accessor :config

    def initialize( file_name )
      @file_name = file_name
      @config    = { :rake_builder  => { :config_file => { :version=> '1.0' } },
                     :include_paths => [] }
    end

    def load
      @config = YAML.load_file( @file_name )

      version = @config[ :rake_builder ][ :config_file ][ :version ]
      raise Rake::Builder::BuilderError.new( 'Config file version missing' ) if version.nil?

      @config[ :include_paths ] ||= []
    end

    def save
      File.open( @file_name, 'w' ) do | file |
        file.write @config.to_yaml
      end
    end

    def include_paths
      @config[ :include_paths ]
    end

    def include_paths=( include_paths )
      @config[ :include_paths ] = include_paths
    end

  end

end
