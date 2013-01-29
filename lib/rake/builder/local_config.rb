require 'yaml'

class Rake::Builder
  class LocalConfig
    VERSIONS = ['1.0', '1.1']

    attr_accessor :include_paths
    attr_accessor :compilation_options

    def initialize(file_name)
      @file_name           = file_name
      @include_paths       = []
      @compilation_options = []
    end

    def load
      config = YAML.load_file(@file_name)

      version              = config[:rake_builder][:config_file][:version]
      if not VERSIONS.include?(version)
        raise Rake::Builder::Error.new('Config file version incorrect') 
      end
      @include_paths       = config[:include_paths]
      @compilation_options = config[:compilation_options]
    end

    def save
      File.open(@file_name, 'w') do |file|
        file.write config.to_yaml
      end
    end

    private

    def config
      {
        :rake_builder        => {:config_file => {:version => VERSIONS[-1]}},
        :include_paths       => @include_paths,
        :compilation_options => @compilation_options
      }
    end
  end
end

