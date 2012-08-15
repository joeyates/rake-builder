load File.dirname(__FILE__) + '/spec_helper.rb'

describe 'when building a cross compilation project' do

  include RakeBuilderHelper

  before( :each ) do
    Rake::Task.clear
    @project = c_task( :executable )
    @project.cross_compile = 'arm-none-eabi-'
    class << @project
      def commands
        build_commands.to_s
      end
    end
  end

  it "respects the cross compilation prefix" do
    @project.commands.should include("arm-none-eabi-gcc")
  end

  it "respects the prefix also for archive tools" do
    @project.target_type = :static_library
    @project.commands.should include("arm-none-eabi-ar")
    @project.commands.should include("arm-none-eabi-ranlib")
  end

  it "builds a shared library with cross compiler" do
    @project.target_type = :shared_library
    @project.commands.should include("arm-none-eabi-gcc")
  end
end
