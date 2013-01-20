load File.dirname(__FILE__) + '/spec_helper.rb'

require 'json'

describe 'when handling generated files' do
  include RakeBuilderHelper

  before( :each ) do
    Rake::Task.clear
    @project = cpp_builder(:executable)
    @expected_generated = Rake::Path.expand_all_with_root(
                            [
                             'main.o',
                             'rake-builder-testfile.txt',
                             @project.makedepend_file,
                             @project.target ],
                            RakeBuilderHelper::SPEC_PATH )
  end

  after( :each ) do
    Rake::Task[ 'clean' ].execute
  end

  it 'lists generated files, with a method' do
    @project.generated_files.should =~ @expected_generated
  end

  it 'removes generated files with \'clean\'' do
    Rake::Task[ 'run' ].invoke
    @expected_generated.each do |f|
      exist?( f ).should be_true
    end
    Rake::Task[ 'clean' ].invoke
    @expected_generated.each do |f|
      exist?( f ).should be_false
    end
  end

end

describe 'when adding generated files' do

  include RakeBuilderHelper

  before( :each ) do
    @file = 'foobar.txt'
    @file_with_path = Rake::Path.expand_with_root( @file, RakeBuilderHelper::SPEC_PATH )
  end

  it 'includes added files' do
    @project = cpp_builder(:executable) do |app|
      app.generated_files << @file_with_path
    end
    @project.generated_files.include?( @file_with_path ).should be_true
  end

  it 'expands the paths of added files' do
    @project = cpp_builder(:executable) do |app|
      app.generated_files << @file
    end
    @project.generated_files.include?( @file_with_path ).should be_true
  end

end
