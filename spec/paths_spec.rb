load File.dirname(__FILE__) + '/spec_helper.rb'

PATHS_SPEC_PATH = File.expand_path( File.dirname(__FILE__) )

describe 'when creating tasks' do

  include RakeBuilderHelper
  include FileUtils

  before( :each ) do
    Rake::Task.clear
  end

  it 'remembers the Rakefile path' do
    builder = Rake::Builder.new do |builder|
      builder.source_search_paths = [ 'cpp_project' ]
    end
    builder.rakefile_path.should == PATHS_SPEC_PATH
  end

  it 'puts everything in objects_path' do
    builder = Rake::Builder.new do |builder|
      builder.source_search_paths = [ 'cpp_project' ]
      builder.objects_path = 'test_directory'
    end
    path = File.join(PATHS_SPEC_PATH, 'test_directory')
    File.dirname(builder.target).should == path
    builder.generated_files.map{ |d| File.dirname(d).should == path }
  end
end

