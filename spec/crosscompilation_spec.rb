load File.dirname(__FILE__) + '/spec_helper.rb'

describe 'when building a cross compilation project' do

  include RakeBuilderHelper

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

  it "respects the cross compilation prefix" do
    @project.print_commands.should include("arm-none-eabi-gcc")
  end

end
