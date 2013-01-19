require 'rspec'
require File.expand_path( File.dirname(__FILE__) + '/../lib/rake/builder' )

module RakeBuilderHelper

  SPEC_PATH ||= File.expand_path( File.dirname(__FILE__) )
  TARGET    ||= {
    :executable      => 'the_executable',
    :static_library  => 'libthe_static_library.a',
    :shared_library  => 'libthe_dynamic_library.so',
  }

  def cpp_task( type, namespace = nil )
    Rake::Builder.new do |builder|
      builder.programming_language = 'c++'
      builder.target               = TARGET[ type ]
      builder.task_namespace       = namespace
      builder.source_search_paths  = [ 'cpp_project' ]
      builder.include_paths        = [ 'cpp_project' ]
      builder.generated_files      << 'rake-builder-testfile.txt'
      yield builder if block_given?
    end
  end

  def c_task( type, namespace = nil )
    Rake::Builder.new do |builder|
      builder.programming_language = 'c'
      builder.target               = TARGET[ type ]
      builder.task_namespace       = namespace
      builder.source_search_paths  = [ 'c_project' ]
      builder.include_paths        = [ 'c_project' ]
      builder.generated_files      << 'rake-c-testfile.txt'
      yield builder if block_given?
    end
  end

  def objective_c_task( type, namespace = nil )
    Rake::Builder.new do |builder|
      builder.programming_language = 'objective-c'
      builder.target               = TARGET[ type ]
      builder.task_namespace       = namespace
      builder.source_search_paths  = [ 'objective_c_project' ]
      builder.include_paths        = [ 'objective_c_project' ]
      builder.generated_files      << 'rake-builder-testfile.txt'
      builder.library_dependencies = [ 'objc' ]
      builder.linker_options       = '-framework CoreFoundation -framework Foundation'
      yield builder if block_given?
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
    originals = [$stdout, $stderr]
    stdout, stderr = StringIO.new, StringIO.new
    $stdout, $stderr = stdout, stderr
    yield
    [stdout.string, stderr.string]
  ensure
    $stdout, $stderr = *originals
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
