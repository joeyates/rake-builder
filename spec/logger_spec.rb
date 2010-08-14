require File.dirname(__FILE__) + '/spec_helper.rb'

describe 'the logger' do

  it 'can be read' do
    cpp = Rake::Cpp.new do |cpp|
      cpp.source_search_paths = [ 'cpp_project' ]
    end
    cpp.logger.should_not be_nil
  end

  it 'can be set' do
    cpp = Rake::Cpp.new do |cpp|
      cpp.source_search_paths = [ 'cpp_project' ]
    end
    lambda do
      cpp.logger = Logger.new( STDOUT )
    end.should_not raise_exception
  end

end
