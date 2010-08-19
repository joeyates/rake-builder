require File.dirname(__FILE__) + '/spec_helper.rb'

describe 'when building a C project' do

  include RakeBuilderHelper

  before( :all ) do
    @test_output_file = Rake::Builder.expand_path_with_root( 'rake-c-testfile.txt', SPEC_PATH )
  end

  before( :each ) do
    Rake::Task.clear
    @project = c_task( :executable )
    @expected_generated = Rake::Builder.expand_paths_with_root( [ './main.o',  @project.makedepend_file, @project.target ], SPEC_PATH )
    `rm -f #{ @test_output_file }`
    `rm -f #{ @project.target }`
  end

  after( :each ) do
    Rake::Task[ 'clean' ].invoke
    `rm -f #{ @test_output_file }`
  end

  it 'builds the program with \'build\'' do
    Rake::Task[ 'build' ].invoke
    exist?( @project.target ).should be_true
  end

  it 'runs the program with \'run\'' do
    Rake::Task[ 'run' ].invoke
    exist?( @test_output_file ).should be_true
  end

end
