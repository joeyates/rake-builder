require 'rubygems' if RUBY_VERSION < '1.9'
require 'logger'
require 'rake'
require 'rake/tasklib'
require 'rake/loaders/makefile'

module Rake

  # A task whose behaviour depends on a FileTask
  class FileTaskAlias < Task

    attr_accessor :target

    def self.define_task( name, target, &block )
      alias_task = super( { name => [] }, &block )
      alias_task.target = target
      alias_task.prerequisites.unshift( target )
      alias_task
    end

    def needed?
      Rake::Task[ @target ].needed?
    end

  end

  # Error indicating that the project failed to build.
  class BuildFailureError < StandardError
  end

  class Builder < TaskLib

    module VERSION #:nodoc:
      MAJOR = 0
      MINOR = 0
      TINY  = 8
 
      STRING = [ MAJOR, MINOR, TINY ].join('.')
    end

    # Expand path to an absolute path relative to the supplied root
    def self.expand_path_with_root( path, root )
      if path =~ /^\//
        File.expand_path( path )
      else
        File.expand_path( root + '/' + path )
      end
    end

    # Expand an array of paths to absolute paths relative to the supplied root
    def self.expand_paths_with_root( paths, root )
      paths.map{ |path| expand_path_with_root( path, root ) }
    end

    # The file to be built
    attr_accessor :target

    # The type of file to be built
    # One of: :executable, :static_library, :shared_library
    # If not set, this is deduced from the target.
    attr_accessor :target_type

    # The types of file that can be built
    TARGET_TYPES = [ :executable, :static_library, :shared_library ]

    # The programming language: 'c++' or 'c' (default 'c++')
    # This also sets defaults for source_file_extension
    attr_accessor :programming_language

    # Programmaing languages that Rake::Builder can handle
    KNOWN_LANGUAGES = {
      'c' => {
        :source_file_extension => 'c',
        :compiler              => 'gcc',
        :linker                => 'gcc'
      },
      'c++' => {
        :source_file_extension => 'cpp',
        :compiler              => 'g++',
        :linker                => 'g++'
      },
      'objective-c' => {
        :source_file_extension => 'm',
        :compiler              => 'gcc',
        :linker                => 'gcc'
      },
    }

    # The compiler that will be used
    attr_accessor :compiler

    # The linker that will be used
    attr_accessor :linker

    # Extension of source files (default 'cpp' for C++ and 'c' fo C)
    attr_accessor :source_file_extension

    # Extension of header files (default 'h')
    attr_accessor :header_file_extension

    # The path of the Rakefile
    # All paths are relative to this
    attr_reader   :rakefile_path

    # The Rakefile
    # The file is not necessarily called 'Rakefile'
    # It is the file which calls to Rake::Builder.new
    attr_reader   :rakefile

    # Directories containing project source files
    attr_accessor :source_search_paths

    # Directories containing project header files
    attr_accessor :header_search_paths

    # (Optional) namespace for tasks
    attr_accessor :task_namespace

    # Name of the default task
    attr_accessor :default_task

    # Tasks which the target file depends upon
    attr_accessor :target_prerequisites

    # Directory to be used for object files
    attr_accessor :objects_path

    # extra options to pass to the compiler
    attr_accessor :compilation_options

    # Additional include directories for compilation
    attr_accessor :include_paths

    # Additional library directories for linking
    attr_accessor :library_paths

    # Libraries to be linked
    attr_accessor :library_dependencies

    # The directory where 'rake install' will copy the target file
    attr_accessor :install_path

    # Name of the generated file containing source - header dependencies
    attr_reader   :makedepend_file

    # Temporary files generated during compilation and linking
    attr_accessor :generated_files

    # Each instance has its own logger
    attr_accessor :logger

    def initialize( &block )
      save_rakefile_info( caller[0] )
      initialize_attributes
      block.call( self )
      configure
      define_tasks
      define_default
    end

    # Source files found in source_search_paths
    def source_files
      @source_fies ||= find_files( @source_search_paths, @source_file_extension )
    end

    # Header files found in header_search_paths
    def header_files
      @header_files ||= find_files( @header_search_paths, @header_file_extension )
    end

    private

    def initialize_attributes
      @logger                = Logger.new( STDOUT )
      @logger.level          = Logger::UNKNOWN
      @programming_language  = 'c++'
      @header_file_extension = 'h'
      @objects_path          = @rakefile_path.dup
      @generated_files       = []
      @library_paths         = []
      @library_dependencies  = []
      @target_prerequisites  = []
      @source_search_paths   = [ @rakefile_path.dup ]
      @header_search_paths   = [ @rakefile_path.dup ]
      @target                = 'a.out'
      @generated_files       = []
    end

    def configure
      @programming_language.downcase!
      raise "Don't know how to build '#{ @programming_language }' programs" if KNOWN_LANGUAGES[ @programming_language ].nil?
      @compiler              ||= KNOWN_LANGUAGES[ @programming_language ][ :compiler ]
      @linker                ||= KNOWN_LANGUAGES[ @programming_language ][ :linker ]
      @source_file_extension ||= KNOWN_LANGUAGES[ @programming_language ][ :source_file_extension ]

      @source_search_paths   = Rake::Builder.expand_paths_with_root( @source_search_paths, @rakefile_path )
      @header_search_paths   = Rake::Builder.expand_paths_with_root( @header_search_paths, @rakefile_path )
      @library_paths         = Rake::Builder.expand_paths_with_root( @library_paths, @rakefile_path )

      raise "The target name cannot be nil" if @target.nil?
      raise "The target name cannot be an empty string" if @target == ''
      @objects_path          = Rake::Builder.expand_path_with_root( @objects_path, @rakefile_path )
      @target                = Rake::Builder.expand_path_with_root( @target, @objects_path )
      @target_type           ||= type( @target )
      raise "Building #{ @target_type } targets is not supported" if ! TARGET_TYPES.include?( @target_type )
      @install_path          ||= default_install_path( @target_type )

      @compilation_options   ||= ''
      @include_paths         ||= @header_search_paths.dup
      @include_paths         = Rake::Builder.expand_paths_with_root( @include_paths, @rakefile_path )
      @generated_files       = Rake::Builder.expand_paths_with_root( @generated_files, @rakefile_path )

      @default_task          ||= :build
      @target_prerequisites  << @rakefile

      @makedepend_file       = @objects_path + '/.' + target_basename + '.depend.mf'

      raise "No source files found" if source_files.length == 0
    end

    def define_tasks
      if @task_namespace
        namespace @task_namespace do
          define
        end
      else
        define
      end
    end

    def define_default
      name = scoped_task( @default_task )
      desc "Equivalent to 'rake #{ name }'"
      if @task_namespace
        task @task_namespace => [ name ]
      else
        task :default => [ name ]
      end
    end

    def define
      if @target_type == :executable
        desc "Run '#{ target_basename }'"
        task :run => :build do
          command = "cd #{ @rakefile_path } && #{ @target }" 
          puts shell( command, Logger::INFO )
        end
      end

      desc "Compile and build '#{ target_basename }'"
      FileTaskAlias.define_task( :build, @target )

      desc "Build '#{ target_basename }'"
      file @target => [ scoped_task( :compile ), @target_prerequisites ] do |t|
        shell "rm -f #{ t.name }"
        case @target_type
        when :executable
          shell "#{ @linker } #{ link_flags } -o #{ @target } #{ file_list( object_files ) }"
        when :static_library
          @logger.add( Logger::INFO, "Builing library '#{ t.name }'" )
          shell "ar -cq #{ t.name } #{ file_list( object_files ) }"
        when :shared_library
          @logger.add( Logger::INFO, "Builing library '#{ t.name }'" )
          shell "#{ @linker } -shared -o #{ t.name } #{ file_list( object_files ) } #{ link_flags }"
        end
        raise BuildFailureError if ! File.exist?( t.name )
      end

      desc "Compile all sources"
      # Only import dependencies when we're compiling
      # otherwise makedepend gets run on e.g. 'rake -T'
      task :compile => [ @makedepend_file, scoped_task( :load_makedepend ), *object_files ]

      source_files.each do |src|
        object = object_path( src )
        @generated_files << object
        file object => [ src ] do |t|
          @logger.add( Logger::INFO, "Compiling '#{ src }'" )
          shell "#{ @compiler } #{ compiler_flags } -c -o #{ object } #{ src }"
        end
      end

      file @makedepend_file => [ *project_files ] do
        @logger.add( Logger::DEBUG, "Analysing dependencies" )
        command = "makedepend -f- -- #{ include_path } -- #{ file_list( source_files ) } 2>/dev/null > #{ @makedepend_file }"
        shell command
      end

      task :load_makedepend => @makedepend_file do |t|
        object_to_source = source_files.inject( {} ) do |memo, source|
          mapped_object = source.gsub( '.' + @source_file_extension, '.o' )
          memo[ mapped_object ] = source
          memo
        end
        File.open( @makedepend_file ).each_line do |line|
          next if line !~ /:\s/
          mapped_object_file = $`
          header_file = $'.gsub( "\n", '' )
          # Why does it work
          # if I make the object (not the source) depend on the header
          source_file = object_to_source[ mapped_object_file ]
          object_file = object_path( source_file )
          object_file_task = Rake.application[ object_file ]
          object_file_task.enhance( [ header_file ] )
        end
      end

      desc 'List generated files (which are remove with \'rake clean\')'
      task :generated_files do
        puts @generated_files.inspect
      end

      # Re-implement :clean locally for project and within namespace
      # Standard :clean is a singleton
      desc "Remove temporary files"
      task :clean do
        @generated_files.each do |file|
          shell "rm -f #{ file }"
        end
      end

      @generated_files << @target
      @generated_files << @makedepend_file

      desc "Install '#{ target_basename }' in '#{ @install_path }'"
      task :install, [] => [ scoped_task( :build ) ] do
        destination = File.join( @install_path, target_basename )
        begin
          shell "cp '#{ @target }' '#{ destination }'", Logger::INFO
        rescue Errno::EACCES => e
          raise "You do not have premission to install '#{ target_basename }' in '#{ @install_path }'\nTry\n $ sudo rake install"
        end
      end

      desc "Uninstall '#{ target_basename }' from '#{ @install_path }'"
      task :uninstall, [] => [] do
        destination = File.join( @install_path, File.basename( @target ) )
        if ! File.exist?( destination )
          @logger.add( Logger::INFO, "The file '#{ destination }' does not exist" )
          next
        end
        begin
          shell "rm '#{ destination }'", Logger::INFO
        rescue Errno::EACCES => e
          raise "You do not have premission to uninstall '#{ destination }'\nTry\n $ sudo rake uninstall"
        end
      end

    end

    def scoped_task( task )
      if @task_namespace
        "#{ task_namespace }:#{ task }"
      else
        task
      end
    end

    def type( target )
      case target
      when /\.a/
        :static_library
      when /\.so/
        :shared_library
      else
        :executable
      end
    end

    # Compiling and linking parameters

    def include_path
      @include_paths.map { |p| "-I#{ p }" }.join( " " )
    end

    def compiler_flags
      include_path + ' ' + @compilation_options
    end

    def link_flags
      [ library_paths_list, library_dependencies_list ].join( " " )
    end

    # Paths

    def save_rakefile_info( caller )
      @rakefile      = caller.match(/^([^\:]+)/)[1]
      @rakefile_path = File.expand_path( File.dirname( @rakefile ) )
    end

    def object_path( source_path_name )
      o_name = File.basename( source_path_name ).gsub( '.' + @source_file_extension, '.o' )
      Rake::Builder.expand_path_with_root( o_name, @objects_path )
    end

    def default_install_path( target_type )
      case target_type
      when :executable
        '/usr/local/bin'
      else  
        '/usr/local/lib'
      end
    end

    def target_basename
      File.basename( @target )
    end

    # Lists of files

    def find_files( paths, extension )
      files = paths.reduce( [] ) do |memo, path|
        glob = ( path =~ /[\*\?]/ ) ? path : path + '/*.' + extension
        memo + FileList[ glob ]
      end
      Rake::Builder.expand_paths_with_root( files, @rakefile_path )
    end

    # TODO: make this return a FileList, not a plain Array
    def object_files
      source_files.map { |file| object_path( file ) }
    end

    def project_files
      source_files + header_files
    end

    def file_list( files )
      files.join( " " )
    end
    
    def library_paths_list
      @library_paths.map { |l| "-L#{ l }" }.join( " " )
    end
    
    def library_dependencies_list
      @library_dependencies.map { |l| "-l#{ l }" }.join( " " )
    end

    def shell( command, log_level = Logger::ERROR )
      @logger.add( log_level, command )
      `#{ command }`
    end

  end

end
