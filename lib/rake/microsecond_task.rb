require 'fileutils'

module Rake
  module Microsecond
    class Base < Task
      attr_accessor :timestamp

      def prerequisites_needed?
        prerequisites.any? do |n|
          task = application[n]
          if task.is_a?(Rake::FileTask) or
            task.is_a?(self.class)
            task.timestamp > @timestamp
          else
            task.needed?
          end
        end
      end
    end

    # Compensate for file systems with 1s resolution
    class FileTask < Base
      def self.define_task( *args, &block )
        task = super( *args, &block )
        task.timestamp = nil
        task
      end

      def needed?
        return true if not File.exist?(self.name)
        @timestamp = File.stat(self.name).mtime if @timestamp.nil?
        prerequisites_needed?
      end

      def execute(*args)
        @timestamp = Time.now
        super(*args)
      end
    end

    class DirectoryTask < Base
      include FileUtils

      attr_accessor :path

      def self.define_task(*args, &block)
        task           = super(*args, &block)
        task.path      = args[0]
        task.timestamp = nil
        task
      end

      def needed?
        return true if not File.directory?(self.path)
        if @timestamp.nil?
          @timestamp = File.stat(self.path).mtime
        end
        prerequisites_needed?
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

