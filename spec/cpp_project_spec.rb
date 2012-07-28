load File.dirname(__FILE__) + '/spec_helper.rb'

describe 'when building an executable' do

  include RakeBuilderHelper

  before( :all ) do
    @test_output_file = Rake::Path.expand_with_root(
                          'rake-builder-testfile.txt', RakeBuilderHelper::SPEC_PATH )
    @expected_target  = Rake::Path.expand_with_root(
                          RakeBuilderHelper::TARGET[ :executable ],
                          RakeBuilderHelper::SPEC_PATH )
  end

  before( :each ) do
    Rake::Task.clear
    @project = cpp_task( :executable )
    `rm -f #{ @test_output_file }`
    `rm -f #{ @project.target }`
  end

  after( :each ) do
    Rake::Task[ 'clean' ].invoke
    `rm -f #{ @test_output_file }`
  end

  it 'knows the target' do
    @project.target.should == @expected_target
  end

  it 'builds the target in the objects directory' do
    File.dirname( @project.target ).should == @project.objects_path
  end

  it 'knows the project type' do
    @project.target_type.should == :executable
  end

  it 'creates the correct tasks' do
    expected_tasks = expected_tasks( [ @project.target ] )
    missing_tasks = expected_tasks - task_names
    missing_tasks.should == []
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

  include RakeBuilderHelper

  before( :each ) do
    Rake::Task.clear
    @project = cpp_task( :executable, 'my_namespace' )
  end

  after( :each ) do
    Rake::Task[ 'my_namespace:clean' ].invoke
  end

  it 'creates the correct tasks' do
    expected = expected_tasks( [ @project.target ], 'my_namespace' )
    missing_tasks = expected - task_names
    missing_tasks.should == []
  end

end

describe 'when building a static library' do

  include RakeBuilderHelper

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

  include RakeBuilderHelper

  before( :each ) do
    Rake::Task.clear
    @project = cpp_task( :shared_library )
    @project.compilation_options << '-fPIC'
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

describe 'when installing' do

  include RakeBuilderHelper

  INSTALL_DIRECTORY = '/tmp/rake-builder-test-install'

  before( :each ) do
    Rake::Task.clear
    `mkdir #{ INSTALL_DIRECTORY }`
    @project = cpp_task( :executable ) do |builder|
      builder.install_path = INSTALL_DIRECTORY
    end
    @installed_target = File.join( INSTALL_DIRECTORY, File.basename( @project.target ) )
  end
  
  after( :each ) do
    `rm -rf #{ INSTALL_DIRECTORY }`
  end

  it 'should install the file' do
    Rake::Task[ 'install' ].invoke
    exist?( @installed_target ).should be_true
  end

  it 'should uninstall the file' do
    Rake::Task[ 'install' ].invoke
    exist?( @installed_target ).should be_true
    Rake::Task[ 'uninstall' ].invoke
    exist?( @installed_target ).should be_false
  end

end
