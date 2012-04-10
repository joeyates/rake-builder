load File.dirname(__FILE__) + '/spec_helper.rb'

describe 'the logger' do

  it 'can be read' do
    builder = Rake::Builder.new do |builder|
      builder.source_search_paths = [ 'cpp_project' ]
    end
    builder.logger.should_not be_nil
  end

  it 'can be set' do
    builder = Rake::Builder.new do |builder|
      builder.source_search_paths = [ 'cpp_project' ]
    end
    lambda do
      builder.logger = Logger.new( STDOUT )
    end.should_not raise_exception
  end

  # TODO: check the output
  # builder.logger.level = Logger::DEBUG

end
