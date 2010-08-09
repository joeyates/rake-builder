require File.dirname(__FILE__) + '/../spec_helper.rb'

SPEC_PATH = File.expand_path( File.dirname(__FILE__) )

module RakeCppHelper

  TARGET = {
    :executable      => 'the_executable',
    :static_library  => 'libthe_static_library.a',
    :shared_library  => 'libthe_dynamic_library.so',
  }

  def task( type, namespace = nil )
    Rake::Cpp.new do |cpp|
      cpp.target               = TARGET[ type ]
      cpp.task_namespace       = namespace
      cpp.source_search_paths  = [ '.' ]
      cpp.header_search_paths  = [ '.' ]
      cpp.objects_path         = '.'
      cpp.include_paths        = [ '.' ]
      cpp.library_dependencies = []
    end
  end

  def cd( p )
    Dir.chdir p
  end

  def touch( file )
    `touch #{file}`
  end

  def exist?( file )
    File.exist? file
  end

  def full_path( file )
    SPEC_PATH + '/' + file
  end

  def full_paths( files )
    files.map{ |file| full_path( file ) }.sort
  end

  def task_names
    Rake::Task.tasks.map( &:to_s )
  end

  def default_tasks
    [ 'build', 'clean', 'compile', 'dependencies' ]
  end

  def expected_tasks( extras, scope = nil )
    t = scoped_tasks( default_tasks, scope )
    t += extras
    t << if scope.nil?
           'default'
         else
           scope
         end
    t
  end

  def scoped_tasks( tasks, scope )
    return tasks if scope.nil?
    tasks.map{ |t| "#{scope}:#{t}" }
  end

end

describe 'The class' do

  it 'has a logger' do
    Rake::Cpp.logger.should_not be_nil
  end

end

describe 'When instantiating a task' do

  before( :each ) do
    Rake::Task.clear
  end

  it 'raises an error when the target is nil/empty' do
    lambda do
      Rake::Cpp.new do |cpp|
        cpp.target = nil
      end
    end.should raise_error
  end

  it 'raises an error when the supplied target_type is unknown' do
    lambda do
      project = Rake::Cpp.new do |cpp|
        cpp.target      = 'my_prog'
        cpp.target_type = :foo
      end
    end.should raise_error
  end

end

describe 'When building an executable' do

  include RakeCppHelper

  before( :all ) do
    cd SPEC_PATH
    @test_output_file = 'testfile.txt'
  end

  before( :each ) do
    Rake::Task.clear
    @project = task( :executable )
    @expected_generated = full_paths( [ 'main.o' ] ) + [ @project.makedepend_file, @project.target ]
  end

  after( :each ) do
    Rake::Task[ 'clean' ].invoke
    `rm -f #{@test_output_file}`
  end

  it 'knows the target' do
    @project.target.should == RakeCppHelper::TARGET[ :executable ]
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
    expected_sources = full_paths [ 'main.cpp' ]
    @project.source_files.should == expected_sources
  end

  it 'finds header files' do
    expected_headers = full_paths [ 'main.h' ]
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
    `rm -f #{@project.target}`
    Rake::Task[ 'build' ].invoke
    exist?( @project.target ).should be_true
  end

  it 'has a \'run\' task' do
    Rake::Task[ 'run' ].should_not be_nil
  end

  it 'builds the program with \'run\'' do
    `rm -f #{@project.target}`
    Rake::Task[ 'run' ].invoke
    exist?( @project.target ).should be_true
  end

  it 'runs the program with \'run\'' do
    `rm -f #{@test_output_file}`
    Rake::Task[ 'run' ].invoke
    exist?( @test_output_file ).should be_true
  end

end

describe 'When using namespaces' do

  include RakeCppHelper

  before( :all ) do
    cd SPEC_PATH
  end

  before( :each ) do
    Rake::Task.clear
    @project = task( :executable, 'my_namespace' )
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

describe 'When building a static library' do

  include RakeCppHelper

  before( :all ) do
    cd SPEC_PATH
  end

  before( :each ) do
    Rake::Task.clear
    @project = task( :static_library )
  end

  after( :each ) do
    Rake::Task[ 'clean' ].invoke
  end

  it 'knows the target type' do
    @project.target_type.should == :static_library
  end

  it 'builds the library' do
    `rm -f #{@project.target}`
    Rake::Task[ 'build' ].invoke
    exist?( @project.target ).should be_true
  end

  it 'hasn\'t got a \'run\' task' do
    task_names.include?( 'run' ).should be_false
  end

end

describe 'When building a shared library' do

  include RakeCppHelper

  before( :all ) do
    cd SPEC_PATH
  end

  before( :each ) do
    Rake::Task.clear
    @project = task( :shared_library )
  end

  after( :each ) do
    Rake::Task[ 'clean' ].invoke
  end

  it 'knows the target type' do
    @project.target_type.should == :shared_library
  end

  it 'builds the library' do
    `rm -f #{@project.target}`
    Rake::Task[ 'build' ].invoke
    exist?( @project.target ).should be_true
  end

  it 'hasn\'t got a \'run\' task' do
    task_names.include?( 'run' ).should be_false
  end

end
