require File.dirname(__FILE__) + '/spec_helper.rb'

describe 'when building an executable' do

  include RakeCppHelper

  before( :all ) do
    @test_output_file = 'testfile.txt'
  end

  before( :each ) do
    Rake::Task.clear
    @project = cpp_task( :executable )
    @expected_generated = Rake::Cpp.expand_paths_with_root( [ './main.o',  @project.makedepend_file, @project.target ], SPEC_PATH )
    `rm -f #{ @test_output_file }`
    `rm -f #{ @project.target }`
  end

  after( :each ) do
    Rake::Task[ 'clean' ].invoke
    `rm -f #{ @test_output_file }`
  end

  it 'knows the target' do
    @project.target.should == Rake::Cpp.expand_path_with_root( RakeCppHelper::TARGET[ :executable ], SPEC_PATH )
  end

  it 'knows the project type' do
    @project.target_type.should == :executable
  end

  it 'creates the correct tasks' do
    expected_tasks = expected_tasks( [ @project.target ] )
    missing_tasks = expected_tasks - task_names
    missing_tasks.should == []
  end

  it 'finds source files' do
    expected_sources = Rake::Cpp.expand_paths_with_root( [ 'cpp_project/main.cpp' ], SPEC_PATH )
    @project.source_files.should == expected_sources
  end

  it 'finds header files' do
    expected_headers = Rake::Cpp.expand_paths_with_root( [ 'cpp_project/main.h' ], SPEC_PATH )
    @project.header_files.should == expected_headers
  end

  it 'lists generated files' do
    @project.generated_files.sort.should == @expected_generated.sort
  end

  it 'removes generated files with \'clean\'' do
    @expected_generated.each do |f|
      touch f
    end
    Rake::Task[ 'clean' ].invoke
    @expected_generated.each do |f|
      exist?( f ).should be_false
    end
  end

  it 'builds the program with \'build\'' do
    Rake::Task[ 'build' ].invoke
    exist?( @project.target ).should be_true
  end

  it 'has a \'run\' task' do
    Rake::Task[ 'run' ].should_not be_nil
  end

  it 'builds the program with \'run\'' do
    Rake::Task[ 'run' ].invoke
    exist?( @project.target ).should be_true
  end

  it 'runs the program with \'run\'' do
    Rake::Task[ 'run' ].invoke
    exist?( @test_output_file ).should be_true
  end

end

describe 'when using namespaces' do

  include RakeCppHelper

  before( :all ) do
    #cd SPEC_PATH
  end

  before( :each ) do
    Rake::Task.clear
    @project = cpp_task( :executable, 'my_namespace' )
  end

  after( :each ) do
    Rake::Task[ 'my_namespace:clean' ].invoke
  end

  it 'creates the correct tasks' do
    expected_tasks = expected_tasks( [ @project.target ], 'my_namespace' )
    missing_tasks = expected_tasks - task_names
    missing_tasks.should == []
  end

end

describe 'when building a static library' do

  include RakeCppHelper

  before( :all ) do
    #cd SPEC_PATH
  end

  before( :each ) do
    Rake::Task.clear
    @project = cpp_task( :static_library )
    `rm -f #{@project.target}`
  end

  after( :each ) do
    Rake::Task[ 'clean' ].invoke
  end

  it 'knows the target type' do
    @project.target_type.should == :static_library
  end

  it 'builds the library' do
    Rake::Task[ 'build' ].invoke
    exist?( @project.target ).should be_true
  end

  it 'hasn\'t got a \'run\' task' do
    task_names.include?( 'run' ).should be_false
  end

end

describe 'when building a shared library' do

  include RakeCppHelper

  before( :all ) do
    #cd SPEC_PATH
  end

  before( :each ) do
    Rake::Task.clear
    @project = cpp_task( :shared_library )
    `rm -f #{ @project.target }`
  end

  after( :each ) do
    Rake::Task[ 'clean' ].invoke
  end

  it 'knows the target type' do
    @project.target_type.should == :shared_library
  end

  it 'builds the library' do
    Rake::Task[ 'build' ].invoke
    exist?( @project.target ).should be_true
  end

  it 'hasn\'t got a \'run\' task' do
    task_names.include?( 'run' ).should be_false
  end

end
