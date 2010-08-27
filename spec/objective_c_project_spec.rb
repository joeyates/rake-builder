require File.dirname(__FILE__) + '/spec_helper.rb'

describe 'when building an Objective-C executable' do

  include RakeBuilderHelper

  before( :all ) do
    @test_output_file = Rake::Builder.expand_path_with_root(
                          'rake-builder-testfile.txt', SPEC_PATH )
    @expected_target = Rake::Builder.expand_path_with_root(
                         RakeBuilderHelper::TARGET[ :executable ],
                         SPEC_PATH )
  end

  before( :each ) do
    Rake::Task.clear
    @project = objective_c_task( :executable )
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
    lambda do
      Rake::Task[ 'run' ].invoke
    end.should_not raise_exception
    exist?( @test_output_file ).should be_true
  end

end
