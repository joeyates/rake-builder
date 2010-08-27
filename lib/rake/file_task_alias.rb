require 'rubygems' if RUBY_VERSION < '1.9'
require 'rake/tasklib'

module Rake

  # A task whose behaviour depends on a FileTask
  class FileTaskAlias < Task

    attr_accessor :target

    def self.define_task( name, target, &block )
      alias_task = super( { name => [] }, &block )
      alias_task.target = target
      alias_task.prerequisites.unshift( target )
      alias_task
    end

    def needed?
      Rake::Task[ @target ].needed?
    end

  end

end
