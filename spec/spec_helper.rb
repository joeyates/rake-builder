require 'rspec'
require 'simplecov' if RUBY_VERSION > '1.9'

if RUBY_VERSION > '1.9'
  if defined?(GATHER_RSPEC_COVERAGE)
    SimpleCov.start do
      add_filter "/spec/"
      add_filter "/vendor/"
    end
  end
end

require File.expand_path(File.join('..', 'lib', 'rake', 'builder'), File.dirname(__FILE__))

module RakeBuilderHelper
  TARGET    ||= {
    :executable      => 'the_executable',
    :static_library  => 'libthe_static_library.a',
    :shared_library  => 'libthe_dynamic_library.so',
  }

  def cpp_builder(type, namespace = nil)
    Rake::Builder.new do |builder|
      builder.programming_language = 'c++'
      builder.target               = TARGET[type]
      builder.task_namespace       = namespace
      builder.source_search_paths  = ['projects/cpp_project']
      builder.include_paths        = ['projects/cpp_project']
      builder.generated_files      << 'rake-builder-testfile.txt'
      yield builder if block_given?
    end
  end

  def c_task( type, namespace = nil )
    Rake::Builder.new do |builder|
      builder.programming_language = 'c'
      builder.target               = TARGET[type]
      builder.task_namespace       = namespace
      builder.source_search_paths  = ['projects/c_project']
      builder.include_paths        = ['projects/c_project']
      builder.generated_files      << 'rake-c-testfile.txt'
      yield builder if block_given?
    end
  end
end

