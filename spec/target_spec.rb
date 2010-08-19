require File.dirname(__FILE__) + '/spec_helper.rb'

describe 'when creating tasks' do

  before( :each ) do
    Rake::Task.clear
  end

  it 'raises an error when the target is an empty string' do
    lambda do
      Rake::Builder.new do |builder|
        builder.target = ''
        builder.source_search_paths = [ 'cpp_project' ]
      end
    end.should raise_error( RuntimeError )
  end

  it 'raises an error when the target is set to nil' do
    lambda do
      Rake::Builder.new do |builder|
        builder.target = nil
        builder.source_search_paths = [ 'cpp_project' ]
      end
    end.should raise_error( RuntimeError )
  end

  it 'sets the target to \'a.out\' if it is not set' do
    builder = Rake::Builder.new do |builder|
      builder.source_search_paths = [ 'cpp_project' ]
    end
    builder.target.should == Rake::Builder.expand_path_with_root( 'a.out', SPEC_PATH )
  end

  it 'raises an error when the supplied target_type is unknown' do
    lambda do
      project = Rake::Builder.new do |builder|
        builder.target      = 'my_prog'
        builder.target_type = :foo
        builder.source_search_paths = [ 'cpp_project' ]
      end
    end.should raise_error
  end

end
