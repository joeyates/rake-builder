load File.dirname(__FILE__) + '/spec_helper.rb'
require 'fileutils'

describe 'the dependencies system' do

  include RakeBuilderHelper
  include FileUtils

  before( :each ) do
    Rake::Task.clear
    @project = cpp_task( :executable )
    Rake::Task[ 'clean' ].execute
    rm_f @project.local_config, :verbose => false
  end

  after( :each ) do
    Rake::Task[ 'clean' ].execute
  end

  context 'objects_path' do

    it 'should not be needed after being called' do
      Rake::Task[ @project.objects_path ].invoke

      Rake::Task[ @project.objects_path ].needed?.should be_false
    end

  end

  context 'missing_headers' do

    it 'should not be needed after being invoked' do
      Rake::Task[ 'missing_headers' ].needed?.should be_true

      Rake::Task[ 'missing_headers' ].invoke

      Rake::Task[ 'missing_headers' ].needed?.should be_false
    end

  end

  context 'makedepend_file' do

    it 'should create the makedepend_file' do
      exist?( @project.makedepend_file ).should be_false

      Rake::Task[ @project.makedepend_file ].invoke

      exist?( @project.makedepend_file ).should be_true
    end

    it 'should not be older than its prerequisites' do
      t = Rake::Task[ @project.makedepend_file ]
      
      t.invoke

      stamp = t.timestamp
      t.prerequisites.any? { |n| t.application[n].timestamp > stamp }.should be_false
    end

    it 'should have all prerequisites satisfied' do
      t = Rake::Task[ @project.makedepend_file ]
      
      t.invoke

      t.prerequisites.any? { |n| t.application[n].needed? }.should be_false
    end

    it 'should not say the makedepend_file is needed' do
      t = Rake::Task[ @project.makedepend_file ]

      t.needed?.should be_true

      t.invoke

      t.needed?.should be_false
    end

  end

  context 'build' do

    before :each do
      @task = Rake::Task[ 'build' ]
    end

    it 'should have all prerequisites satisfied' do
      @task.invoke

      @task.prerequisites.any? { |n| @task.application[n].needed? }.should be_false
    end

    it 'should create the makedepend_file' do
      exist?( @project.makedepend_file ).should be_false

      Rake::Task[ 'build' ].invoke

      exist?( @project.makedepend_file ).should be_true
    end

    it 'should create the target' do
      Rake::Task[ 'build' ].invoke

      exist?( @project.target ).should be_true
    end

    it 'should say the compile task is up to date' do
      Rake::Task[ 'build' ].invoke

      Rake::Task[ 'compile' ].needed?.should be_false
    end

    it 'should say the build is up to date' do
      Rake::Task[ 'build' ].invoke

      Rake::Task[ 'build' ].needed?.should be_false
    end

    it 'should say the makedepend_file is up to date' do
      exist?( @project.makedepend_file ).should be_false

      isolating_seconds do
        Rake::Task[ 'build' ].invoke
      end

      Rake::Task[ @project.makedepend_file ].needed?.should be_false
    end

    it 'should say the target is up to date' do
      Rake::Task[ 'build' ].invoke

      target_mtime = File.stat( @project.target ).mtime
      @project.target_prerequisites.each do | prerequisite |
        File.stat( prerequisite ).mtime.should be < target_mtime
      end
      Rake::Task[ @project.target ].needed?.should be_false
    end

  end

  it 'doesn\'t recompile objects, if nothing changes' do
    isolating_seconds do
      Rake::Task[ 'compile' ].invoke
    end
    Rake::Task.clear
    @project = cpp_task( :executable )
    object_file_path = Rake::Path.expand_with_root( 'main.o', RakeBuilderHelper::SPEC_PATH )
    Rake::Task[ object_file_path ].needed?.should be_false
  end

  it 'recompiles objects, if a source file changes' do
    isolating_seconds do
      Rake::Task[ 'compile' ].invoke
    end
    Rake::Task.clear
    @project = cpp_task( :executable )
    source_file_path = Rake::Path.expand_with_root( 'cpp_project/main.cpp', RakeBuilderHelper::SPEC_PATH )
    object_file_path = Rake::Path.expand_with_root( 'main.o', RakeBuilderHelper::SPEC_PATH )
    touching_temporarily( source_file_path, File.mtime( object_file_path ) + 1 ) do
      Rake::Task[ object_file_path ].needed?.should be_true
    end
  end

  it 'recompiles source files, if header dependencies are more recent' do
    header_file_path = Rake::Path.expand_with_root( 'cpp_project/main.h', RakeBuilderHelper::SPEC_PATH )
    object_file_path = Rake::Path.expand_with_root( 'main.o', RakeBuilderHelper::SPEC_PATH )
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

  it 'should indicate the target is out of date, if the Rakefile is newer' do
    Rake::Task[ 'build' ].invoke

    Rake::Task[ @project.target ].needed?.should be_false

    Rake::Task.clear
    @project = cpp_task( :executable )
    touching_temporarily( @project.target, File.mtime( @project.rakefile ) - 1 ) do
      Rake::Task[ @project.target ].needed?.should be_true
    end
  end

  it 'should indicate that a build is needed if the Rakefile changes' do
    Rake::Task[ 'build' ].invoke

    Rake::Task[ 'build' ].needed?.should be_false

    Rake::Task.clear
    @project = cpp_task( :executable )
    touching_temporarily( @project.target, File.mtime( @project.rakefile ) - 1 ) do
      Rake::Task[ 'build' ].needed?.should be_true
    end
  end

end
