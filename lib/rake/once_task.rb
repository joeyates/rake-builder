require 'rubygems' if RUBY_VERSION < '1.9'
require 'rake/tasklib'

module Rake
  # A task whick is no longer needed after its first invocation
  class OnceTask < Task
    attr_accessor :invoked
    attr_accessor :timestamp

    def self.define_task(*args, &block)
      task = super(*args, &block)
      task.timestamp = nil
      task.invoked = false
      task
    end

    def execute(*args)
      @timestamp = Time.now
      @invoked = true
      super(*args)
    end

    def needed?
      ! @invoked
    end
  end
end

def once_task(*args, &block)
  Rake::OnceTask.define_task(*args, &block)
end

