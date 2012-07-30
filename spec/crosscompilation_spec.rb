load File.dirname(__FILE__) + '/spec_helper.rb'

describe 'when building a cross compilation project' do

  include RakeBuilderHelper

  before( :all ) do
    #@test_output_file = Rake::Path.expand_with_root( 'rake-c-testfile.txt', RakeBuilderHelper::SPEC_PATH )
  end

  before( :each ) do
    Rake::Task.clear
    @project = c_task( :executable )
    @project.cross_compile = 'arm-none-eabi-'
    class << @project
      def print_commands
        build_commands.to_s
      end
    end
  end

  after( :each ) do
    #Rake::Task[ 'clean' ].invoke
    #`rm -f #{ @test_output_file }`
    #`rm -f '#{ @project.local_config }'`
  end

  it "respects the cross compilation prefix" do
    @project.print_commands.should include("arm-none-eabi-gcc")
  end

end
