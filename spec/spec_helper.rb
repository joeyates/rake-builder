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

module InputOutputTestHelper
  def capturing_output
    originals = $stdout, $stderr
    stdout, stderr = StringIO.new, StringIO.new
    $stdout, $stderr = stdout, stderr
    begin
      yield
    ensure
      $stdout, $stderr = originals
    end
    [stdout.string, stderr.string]
  end
end

