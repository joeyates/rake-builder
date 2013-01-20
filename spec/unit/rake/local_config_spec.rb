require 'spec_helper'

LOCAL_CONFIG_SPEC_PATH = File.expand_path( File.dirname(__FILE__) )

describe Rake::LocalConfig do

  include RakeBuilderHelper

  before( :each ) do
    @local_config_file = Rake::Path.expand_with_root( '.rake-builder', LOCAL_CONFIG_SPEC_PATH )
    @expected_path     = "/some/special/path"
    @config            = {:rake_builder=>{:config_file=>{:version=>"1.0"}}, :include_paths=>[ @expected_path ]}
  end

  after( :each ) do
    `rm -f '#{ @local_config_file }'`
  end

  it 'works if the\'s no config file' do
    lambda do
      @builder = cpp_builder( :executable )
    end.should_not raise_error
  end

  it 'loads config files' do
    save_config
    config = Rake::LocalConfig.new( @local_config_file )
    config.load

    config.include_paths.     should         include( @expected_path )
  end

  it 'fails if the file version is incorrect' do
    @config[ :rake_builder ][ :config_file ].delete( :version )
    save_config
    lambda do
      config = Rake::LocalConfig.new( @local_config_file )
      config.load
    end.should raise_error(Rake::Builder::Error, 'Config file version incorrect')
  end

  context 'dependencies' do

    before( :each ) do
      Rake::Task.clear
      @project = cpp_builder( :executable )
      Rake::Task[ 'clean' ].execute
      `rm -f #{ @project.local_config }`
    end

    context 'when local_config is invoked' do

      it 'should no longer be needed' do
        exist?( @project.local_config ).should be_false
        Rake::Task[ @project.local_config ].needed?.should be_true

        Rake::Task[ @project.local_config ].invoke

        exist?( @project.local_config ).should be_true
        Rake::Task[ @project.local_config ].needed?.should be_false
      end

    end

    context 'when load_local_config is invoked' do

      it 'should no longer be needed' do
        Rake::Task[ 'load_local_config' ].needed?.should be_true

        Rake::Task[ 'load_local_config' ].invoke

        Rake::Task[ 'load_local_config' ].needed?.should be_false
      end

      it 'local_config should no longer be needed' do
        Rake::Task[ @project.local_config ].needed?.should be_true

        Rake::Task[ 'load_local_config' ].invoke

        Rake::Task[ @project.local_config ].needed?.should be_false
      end

    end

  end

  private

  def save_config( config = @config, filename = @local_config_file )
    File.open( filename, 'w' ) do | file |
      file.write config.to_yaml
    end
  end

end
