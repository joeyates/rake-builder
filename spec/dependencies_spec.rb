require File.dirname(__FILE__) + '/spec_helper.rb'

=begin

N.B. This spec file changes *it's own* modification time
to check dependency handling.

=end

describe 'the dependencies' do

  include RakeCppHelper

  before( :each ) do
    Rake::Task.clear
    # The project *must* be created in this file,
    # so that it is this file that gets its
    # modification time updated
    @project = Rake::Cpp.new do |cpp|
      cpp.programming_language = 'c++'
      cpp.target               = 'my_program'
      cpp.source_search_paths  = [ 'cpp_project' ]
      cpp.header_search_paths  = [ 'cpp_project' ]
    end
    Rake::Task[ 'clean' ].execute
  end

  after( :each ) do
    Rake::Task[ 'clean' ].execute
  end

  it 'should make the target depend on the Rakefile' do
    Rake::Task[ @project.target ].prerequisites.include?( @project.rakefile ).should be_true
  end

  it 'should indicate the target is up to date, if nothing changes' do
    Rake::Task[ 'build' ].invoke
    Rake::Task[ @project.target ].needed?.should_not be_true
  end

  it 'should indicate the build is up to date, if nothing changes' do
    Rake::Task[ 'build' ].invoke
    Rake::Task[ 'build' ].needed?.should be_false
  end

  # In our case this spec file is the "Rakefile"
  # i.e., the file that calls Rake::Cpp.new
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
