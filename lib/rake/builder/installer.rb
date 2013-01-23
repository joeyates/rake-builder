require 'fileutils'

class Rake::Builder
  class Installer
    def install(source_pathname, destination_path)
      ensure_file_exists source_pathname
      raise "The path '#{destination_path}' does not exist" unless File.exist?(destination_path)
      raise "'#{destination_path}' is not a directory" unless File.directory?(destination_path)
      ensure_directory_writable destination_path, "Cannot copy files to the directory '#{destination_path}'"
      filename = File.basename(source_pathname)
      destination_pathname = File.join(destination_path, filename)
      if File.file?(destination_pathname) and not File.writable?(destination_pathname)
        raise "The file '#{destination_pathname}' cannot be overwritten"
      end

      FileUtils.copy_file source_pathname, destination_path
    end

    def uninstall(installed_pathname)
      return unless File.exist?(installed_pathname)
      ensure_directory_writable File.dirname(installed_pathname)
      File.unlink installed_pathname
    end

    private

    def ensure_file_exists(pathname)
      raise "File '#{pathname}' does not exist" unless File.exist?(pathname)
    end

    def ensure_directory_writable(path, message = nil)
      message ||= "The directory '#{path}' is not writable"
      raise message unless File.writable?(path)
    end
  end
end

