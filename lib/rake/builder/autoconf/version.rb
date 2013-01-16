class Rake::Builder
  class Version
    def initialize(parameter_version = nil)
      @parameter_version = parameter_version
    end

    def decide
      acceptable_version_string = %r(^(\d+)\.(\d+)\.(\d+)$)
      if @parameter_version && @parameter_version !~ acceptable_version_string
        raise "The supplied version number '#{@parameter_version}' is badly formatted. It should consist of three numbers separated by ."
      end
      file_version = load_file_version
      if file_version && file_version !~ acceptable_version_string
        raise "Your VERSION file contains a version number '#{file_version}' which is badly formatted. It should consist of three numbers separated by ."
      end
      case
      when @parameter_version.nil? && file_version.nil?
        raise <<-EOT
        This task requires a project version: major.minor.revision (e.g. 1.03.0567)
        Please do one of the following:
        - supply a version parameter: rake autoconf[project_name,version]
        - create a VERSION file.
        EOT
      when file_version.nil?
        save_file_version @parameter_version
        return @parameter_version
      when @parameter_version.nil?
        return file_version
      when file_version != @parameter_version
        raise <<-EOT
        The version parameter supplied is different to the value in the VERSION file
        EOT
      else
        return file_version
      end
    end

    private

    def load_file_version
      return nil unless File.exist?('VERSION')
      version = File.read('VERSION')
      version.strip
    end

    def save_file_version(version)
      File.open('VERSION', 'w') { |f| f.write "#{version}\n" }
    end
  end
end

