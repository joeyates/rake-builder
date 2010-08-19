require File.dirname(__FILE__) + '/spec_helper.rb'

PATHS_SPEC_PATH = File.expand_path( File.dirname(__FILE__) )

describe 'when creating tasks' do

  before( :each ) do
    Rake::Task.clear
  end

  it 'remembers the Rakefile path' do
    builder = Rake::Builder.new do |builder|
      builder.source_search_paths = [ 'cpp_project' ]
    end
    builder.rakefile_path.should == PATHS_SPEC_PATH
  end

end

