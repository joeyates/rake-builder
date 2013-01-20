class Rake::Builder
  module Autoconf
  end
end

module Rake::Builder::Autoconf
  class Version
    def initialize(parameter_version = nil)
      @parameter_version = parameter_version
      if @parameter_version and not is_valid?(@parameter_version)
        raise "The supplied version number '#{@parameter_version}' is badly formatted. It should consist of three numbers separated by ."
      end
      @file_version = load_file_version
    end

    def decide
      case
      when @parameter_version.nil? && @file_version.nil?
        raise <<-EOT
        This task requires a project version: major.minor.revision (e.g. 1.03.0567)
        Please do one of the following:
        - supply a version parameter: rake autoconf[project_name,version]
        - create a VERSION file.
        EOT
      when @file_version.nil?
        save_file_version @parameter_version
        return @parameter_version
      when @parameter_version.nil?
        return @file_version
      when @file_version != @parameter_version
        raise <<-EOT
        The version parameter supplied is different to the value in the VERSION file
        EOT
      else
        return @file_version
      end
    end

    private

    def is_valid?(version)
      acceptable_version_string = %r(^(\d+)\.(\d+)\.(\d+)$)
      version.match(acceptable_version_string)
    end

    def load_file_version
      return nil unless File.exist?('VERSION')
      version = File.read('VERSION')
      version.strip!
      if not is_valid?(version)
        raise "Your VERSION file contains a version number '#{version}' which is badly formatted. It should consist of three numbers separated by ."
      end
      version
    end

    def save_file_version(version)
      File.open('VERSION', 'w') { |f| f.write "#{version}\n" }
    end
  end
end

