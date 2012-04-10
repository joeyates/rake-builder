load File.dirname(__FILE__) + '/spec_helper.rb'

LOCAL_CONFIG_SPEC_PATH = File.expand_path( File.dirname(__FILE__) )

describe 'local config files' do

  include RakeBuilderHelper

  before( :each ) do
    @local_config_file = Rake::Path.expand_with_root( '.rake-builder', LOCAL_CONFIG_SPEC_PATH )
    @expected_path     = "/some/special/path"
    @config            = {:rake_builder=>{:config_file=>{:version=>"1.0"}}, :include_paths=>[ @expected_path ]}
    `rm -f '#{ @local_config_file }'`
  end

  it 'works if the\'s no config file' do
    lambda do
      @builder = cpp_task( :executable )
    end.should_not raise_error
  end

  it 'loads config files' do
    save_config
    config = Rake::LocalConfig.new( @local_config_file )
    config.load

    config.include_paths.     should         include( @expected_path )
  end

  it 'fails if there\'s no version' do
    @config[ :rake_builder ][ :config_file ].delete( :version )
    save_config
    lambda do
      config = Rake::LocalConfig.new( @local_config_file )
      config.load
    end.should raise_error( Rake::Builder::BuilderError, 'Config file version missing' )
  end

  private

  def save_config( config = @config, filename = @local_config_file )
    File.open( filename, 'w' ) do | file |
      file.write config.to_yaml
    end
  end

end
