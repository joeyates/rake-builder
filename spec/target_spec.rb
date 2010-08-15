require File.dirname(__FILE__) + '/spec_helper.rb'

describe 'when creating tasks' do

  before( :each ) do
    Rake::Task.clear
  end

  it 'raises an error when the target is an empty string' do
    lambda do
      Rake::Cpp.new do |cpp|
        cpp.target = ''
        cpp.source_search_paths = [ 'cpp_project' ]
      end
    end.should raise_error( RuntimeError )
  end

  it 'raises an error when the target is set to nil' do
    lambda do
      Rake::Cpp.new do |cpp|
        cpp.target = nil
        cpp.source_search_paths = [ 'cpp_project' ]
      end
    end.should raise_error( RuntimeError )
  end

  it 'sets the target to \'a.out\' if it is not set' do
    cpp = Rake::Cpp.new do |cpp|
      cpp.source_search_paths = [ 'cpp_project' ]
    end
    cpp.target.should == Rake::Cpp.expand_path_with_root( 'a.out', SPEC_PATH )
  end

  it 'raises an error when the supplied target_type is unknown' do
    lambda do
      project = Rake::Cpp.new do |cpp|
        cpp.target      = 'my_prog'
        cpp.target_type = :foo
        cpp.source_search_paths = [ 'cpp_project' ]
      end
    end.should raise_error
  end

end
