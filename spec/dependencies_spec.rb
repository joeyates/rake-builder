load File.dirname(__FILE__) + '/spec_helper.rb'

describe 'the dependencies system' do

  include RakeBuilderHelper

  before( :each ) do
    Rake::Task.clear
    @project = cpp_task( :executable )
    Rake::Task[ 'clean' ].execute
  end

  after( :each ) do
    Rake::Task[ 'clean' ].execute
  end

  it 'says the target is up to date, if nothing changes' do
    Rake::Task[ 'build' ].invoke
    Rake::Task[ @project.target ].needed?.should_not be_true
  end

  it 'says the build is up to date, if nothing changes' do
    Rake::Task[ 'build' ].invoke
    Rake::Task[ 'build' ].needed?.should be_false
  end

  it 'doesn\'t recompile objects, if nothing changes' do
    isolating_seconds do
      Rake::Task[ 'compile' ].invoke
    end
    Rake::Task.clear
    @project = cpp_task( :executable )
    object_file_path = Rake::Path.expand_with_root( 'main.o', SPEC_PATH )
    Rake::Task[ object_file_path ].needed?.should be_false
  end

  it 'recompiles objects, if a source file changes' do
    isolating_seconds do
      Rake::Task[ 'compile' ].invoke
    end
    Rake::Task.clear
    @project = cpp_task( :executable )
    source_file_path = Rake::Path.expand_with_root( 'cpp_project/main.cpp', SPEC_PATH )
    object_file_path = Rake::Path.expand_with_root( 'main.o', SPEC_PATH )
    touching_temporarily( source_file_path, File.mtime( object_file_path ) + 1 ) do
      Rake::Task[ object_file_path ].needed?.should be_true
    end
  end

  it 'recompiles source files, if header dependencies' do
    header_file_path = Rake::Path.expand_with_root( 'cpp_project/main.h', SPEC_PATH )
    object_file_path = Rake::Path.expand_with_root( 'main.o', SPEC_PATH )
    isolating_seconds do
      Rake::Task[ 'compile' ].invoke
    end
    Rake::Task.clear
    @project = cpp_task( :executable )
    # Header dependencies aren't loaded until we call :compile
    Rake::Task[ :load_makedepend ].invoke
    touching_temporarily( header_file_path, File.mtime( object_file_path ) + 1 ) do
      Rake::Task[ object_file_path ].needed?.should be_true
    end
  end

end

describe 'Rakefile dependencies' do

  include RakeBuilderHelper

  before( :each ) do
    Rake::Task.clear
    @project = cpp_task( :executable )
    Rake::Task[ 'clean' ].execute
  end

  after( :each ) do
    Rake::Task[ 'clean' ].execute
  end

  it 'should make the target depend on the Rakefile' do
    Rake::Task[ @project.target ].prerequisites.include?( @project.rakefile ).should be_true
  end

  # In our case this spec file is the spec_helper
  # i.e., the file that calls Rake::Builder.new
  it 'should indicate the target is out of date, if the Rakefile is newer' do
    Rake::Task[ 'build' ].invoke
    Rake::Task[ @project.target ].needed?.should be_false
    touching_temporarily( @project.target, File.mtime( @project.rakefile ) - 1 ) do
      Rake::Task[ @project.target ].needed?.should be_true
    end
  end

  it 'should indicate that a build is needed if the Rakefile changes' do
    Rake::Task[ 'build' ].invoke
    Rake::Task[ 'build' ].needed?.should be_false
    touching_temporarily( @project.target, File.mtime( @project.rakefile ) - 1 ) do
      Rake::Task[ 'build' ].needed?.should be_true
    end
  end

end
