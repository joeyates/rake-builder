load File.dirname(__FILE__) + '/spec_helper.rb'
require 'fileutils'

describe Rake::Microsecond::DirectoryTask do

  include RakeBuilderHelper
  include FileUtils

  before :all do
    @path = File.join(File.dirname(__FILE__), 'microsecond_directory')
  end

  before :each do
    rm_rf @path, :verbose => false
  end

  it 'should memorize the directory creation time including fractional seconds' do
    File.directory?( @path ).should be_false

    t = Rake::Microsecond::DirectoryTask.define_task( @path )

    isolating_seconds do
      sleep 0.01
      t.invoke
    end

    File.directory?( @path ).should be_true
    t.timestamp.usec.should_not == 0
  end

end

