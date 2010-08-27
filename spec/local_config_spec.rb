require File.dirname(__FILE__) + '/spec_helper.rb'

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

  it 'loads the local config file' do
    save_config
    @builder = cpp_task( :executable )
    @builder.include_paths.should include( @expected_path )
  end

  it 'fails if there\'s no version' do
    @config[ :rake_builder ][ :config_file ].delete( :version )
    save_config
    lambda do
      @project = cpp_task( :executable )
    end.should raise_error
  end

  it 'for the default namespace, loads only the \'.rake-builder\' config file' do
    namespaced_config_path = @local_config_file + '.foo'
    namespaced_config      = @config.dup
    unexpected_path        = '/this/shouldnt/show/up'
    namespaced_config[ :include_paths ] = [ unexpected_path ]
    save_config
    save_config( namespaced_config, namespaced_config_path )
    @builder = cpp_task( :executable )
    @builder.include_paths.should     include( @expected_path )
    @builder.include_paths.should_not include( unexpected_path )
    `rm -f '#{ namespaced_config_path }'`
  end

  it 'for a particular namespace, loads only that namespace\'s config file' do
    namespaced_config_path = @local_config_file + '.foo'
    namespaced_config      = @config.dup
    unexpected_path        = '/this/shouldnt/show/up'
    namespaced_config[ :include_paths ] = [ unexpected_path ]
    save_config
    save_config( namespaced_config, namespaced_config_path )
    @builder = cpp_task( :executable, 'foo' )
    @builder.include_paths.should_not include( @expected_path )
    @builder.include_paths.should     include( unexpected_path )
    `rm -f '#{ namespaced_config_path }'`
  end

  private

  def save_config( config = @config, filename = @local_config_file )
    File.open( filename, 'w' ) do | file |
      file.write config.to_yaml
    end
  end

end
