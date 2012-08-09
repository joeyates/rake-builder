require 'rubygems' if RUBY_VERSION < '1.9'
require 'rake/tasklib'
require 'fileutils'

module Rake

  module Microsecond
  # Compensate for file systems with 1s resolution

    class FileTask < Task

      attr_accessor :timestamp

      def self.define_task( *args, &block )
        task = super( *args, &block )
        task.timestamp = nil
        task
      end

      def needed?
        return true if ! File.exist?( self.name )
        @timestamp = File.stat( self.name ).mtime if @timestamp.nil?
        return self.prerequisites.any? { | n | ! application[n].timestamp.nil? && application[n].timestamp > @timestamp }
      end

      def execute(*args)
        @timestamp = Time.now
        super(*args)
      end

    end

    class DirectoryTask < Task

      include FileUtils

      attr_accessor :timestamp
      attr_accessor :path

      def self.define_task( *args, &block )
        task           = super(*args, &block)
        task.path      = args[0]
        task.timestamp = nil
        task
      end

      def needed?
        exists = File.directory?(self.path)
        if exists && @timestamp.nil?
          @timestamp = File.stat(self.path).mtime
        end
        ! exists
      end

      def execute(*args)
        mkdir_p self.path, :verbose => false
        @timestamp = Time.now
        super(*args)
      end

    end

  end

end

def microsecond_file(*args, &block)
  Rake::Microsecond::FileTask.define_task(*args, &block)
end

def microsecond_directory(*args, &block)
  Rake::Microsecond::DirectoryTask.define_task(*args, &block)
end

