require File.dirname(__FILE__) + '/spec_helper.rb'

describe 'when using libraries' do

  include RakeBuilderHelper

  before( :each ) do
    Rake::Task.clear
  end

  after( :each ) do
    Rake::Task[ 'clean' ].execute
  end

  it 'builds if libraries are found' do
    lambda do
      @project = cpp_task( :executable ) do |builder|
        builder.library_dependencies = [ 'gcc' ] # As we're using GCC, libgcc.a should always be present
      end
      Rake::Task[ 'build' ].invoke
    end.should_not raise_error
  end

  it 'fails to build if libraries are missing' do
    lambda do
      @project = cpp_task( :executable ) do |builder|
        builder.library_dependencies = [ 'library_that_doesnt_exist' ]
      end
      Rake::Task[ 'build' ].invoke
    end.should raise_error( Rake::BuildFailureError )
  end

end
