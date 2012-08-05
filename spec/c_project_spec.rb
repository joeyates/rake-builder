load File.dirname(__FILE__) + '/spec_helper.rb'

describe 'when building a C project' do

  include RakeBuilderHelper

  before( :all ) do
    @test_output_file = Rake::Path.expand_with_root( 'rake-c-testfile.txt', RakeBuilderHelper::SPEC_PATH )
  end

  before( :each ) do
    Rake::Task.clear
    @project = c_task( :executable )
    @expected_generated = Rake::Path.expand_all_with_root(
      [
      './main.o',
      @project.makedepend_file, @project.target
      ],
      RakeBuilderHelper::SPEC_PATH
    )
    `rm -f #{ @test_output_file }`
    `rm -f #{ @project.target }`
  end

  after( :each ) do
    Rake::Task[ 'clean' ].invoke
    `rm -f #{ @test_output_file }`
    `rm -f '#{ @project.local_config }'`
  end

  it "builds the program with 'build'" do
    Rake::Task[ 'build' ].invoke
    exist?( @project.target ).should be_true
  end

  it "runs the program with 'run'" do
    Rake::Task[ 'run' ].invoke
    exist?( @test_output_file ).should be_true
  end

end
