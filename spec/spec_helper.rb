require 'spec'
require File.dirname(__FILE__) + '/../lib/rake/cpp'

SPEC_PATH = File.expand_path( File.dirname(__FILE__) )

module RakeCppHelper

  TARGET = {
    :executable      => 'the_executable',
    :static_library  => 'libthe_static_library.a',
    :shared_library  => 'libthe_dynamic_library.so',
  }

  def cpp_task( type, namespace = nil )
    Rake::Cpp.new do |cpp|
      cpp.programming_language = 'c++'
      cpp.target               = TARGET[ type ]
      cpp.task_namespace       = namespace
      cpp.source_search_paths  = [ 'cpp_project' ]
      cpp.header_search_paths  = [ 'cpp_project' ]
      cpp.generated_files      << 'rake-cpp-testfile.txt'
      yield cpp if block_given?
    end
  end

  def c_task( type, namespace = nil )
    Rake::Cpp.new do |cpp|
      cpp.programming_language = 'c'
      cpp.target               = TARGET[ type ]
      cpp.task_namespace       = namespace
      cpp.source_search_paths  = [ 'c_project' ]
      cpp.header_search_paths  = [ 'c_project' ]
      cpp.generated_files      << 'rake-c-testfile.txt'
      yield cpp if block_given?
    end
  end

  def touch( file )
    `touch #{file}`
  end

  def exist?( file )
    File.exist? file
  end

  def task_names
    Rake::Task.tasks.map( &:to_s )
  end

  def default_tasks
    [ 'build', 'clean', 'compile', 'load_makedepend' ]
  end

  def expected_tasks( extras, scope = nil )
    t = scoped_tasks( default_tasks, scope )
    t += extras
    t << if scope.nil?
           'default'
         else
           scope
         end
    t
  end

  def scoped_tasks( tasks, scope )
    return tasks if scope.nil?
    tasks.map{ |t| "#{scope}:#{t}" }
  end

  def capturing_output
    output = StringIO.new
    $stdout = output
    yield
    output.string
  ensure
    $stdout = STDOUT
  end

  # Most file systems have a 1s resolution
  # Force a wait into the next second around a task
  # So FileTask's out_of_date? will behave correctly
  def isolating_seconds
    sec = Time.now.sec
    yield
    while( Time.now.sec == sec ) do end
  end

  def touching_temporarily( file, touch_time )
    begin
      atime = File.atime( file )
      mtime = File.mtime( file )
      File.utime( atime, touch_time, file )
      yield
    ensure
      File.utime( atime, mtime, file )
    end
  end

end
