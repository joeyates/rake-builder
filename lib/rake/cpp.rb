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

  class Cpp < TaskLib

    module VERSION #:nodoc:
      MAJOR = 0
      MINOR = 0
      TINY  = 3
 
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

    # Programmaing languages that Rake::Cpp can handle
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
    # It is the file which calls to Rake::Cpp.new
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

    # Additional include directories for compilation
    attr_accessor :include_paths

    # Additional library directories for linking
    attr_accessor :library_paths

    # Libraries to be linked
    attr_accessor :library_dependencies

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
    end

    def configure
      @programming_language.downcase!
      raise "Don't know how to build '#{ @programming_language }' programs" if KNOWN_LANGUAGES[ @programming_language ].nil?
      @compiler              ||= KNOWN_LANGUAGES[ @programming_language ][ :compiler ]
      @linker                ||= KNOWN_LANGUAGES[ @programming_language ][ :linker ]
      @source_file_extension ||= KNOWN_LANGUAGES[ @programming_language ][ :source_file_extension ]

      @source_search_paths   = Rake::Cpp.expand_paths_with_root( @source_search_paths, @rakefile_path )
      @header_search_paths   = Rake::Cpp.expand_paths_with_root( @header_search_paths, @rakefile_path )
      @library_paths         = Rake::Cpp.expand_paths_with_root( @library_paths, @rakefile_path )

      raise "The target name cannot be nil" if @target.nil?
      raise "The target name cannot be an empty string" if @target == ''
      @target                = Rake::Cpp.expand_path_with_root( @target, @rakefile_path )
      @target_type           ||= type( @target )
      raise "Building #{ @target_type } targets is not supported" if ! TARGET_TYPES.include?( @target_type )

      @objects_path          = Rake::Cpp.expand_path_with_root( @objects_path, @rakefile_path )
      @include_paths         ||= @header_search_paths.dup
      @include_paths         = Rake::Cpp.expand_paths_with_root( @include_paths, @rakefile_path )

      @default_task          ||= :build
      @target_prerequisites  << @rakefile

      @makedepend_file       = @objects_path + '/.' + File::basename( @target ) + '.depend.mf'
      @generated_files       = Rake::FileList.new

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
      desc "Equivalent to 'rake #{ scoped_default }'"
      if @task_namespace
        task @task_namespace => [ scoped_default ]
      else
        task :default => [ scoped_default ]
      end
    end

    def define
      file @makedepend_file => [ *project_files ] do
        @logger.add( Logger::DEBUG, "Analysing dependencies" )
        command = "makedepend -f- -- #{ include_path } -- #{ file_list( source_files ) } 2>/dev/null > #{ @makedepend_file }"
        shell command
      end

      # Only import dependencies when we're compiling
      # otherwise makedepend gets run on e.g. 'rake -T'
      task :dependencies => @makedepend_file do |t|
        import @makedepend_file
      end

      source_files.each do |src|
        object = object_path( src )
        @generated_files.include( object )
        rule object => src do |t|
          @logger.add( Logger::INFO, "Compiling '#{ t.source }'" )
          shell "#{ @compiler } #{ compiler_flags } -c -o #{ t.name } #{ t.source }"
        end
      end

      file @target => [ :compile, @target_prerequisites ] do |t|
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

      if @target_type == :executable
        desc "Run '#{ @target }'"
        task :run => :build do
          puts shell( Rake::Cpp.expand_path_with_root( @target, @rakefile_path ), Logger::INFO )
        end
      end

      # Re-implement :clean locally for project and within namespace
      # Standard :clean is a singleton
      desc "Remove temporary files"
      task :clean do
        @generated_files.each do |file|
          shell "rm -f #{ file }"
        end
      end

      @generated_files.include( @target )
      @generated_files.include( @makedepend_file )

      desc "Compile all sources"
      task :compile => [ :dependencies, *object_files ]

      desc "Compile and build '#{ @target }'"
      FileTaskAlias.define_task( :build, @target )

    end

    def scoped_default
      if @task_namespace
        "#{ task_namespace }:#{ @default_task }"
      else
        @default_task
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
      include_path
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
      @objects_path + '/' + o_name
    end

    # Lists of files

    def find_files( paths, extension )
      files = paths.reduce( [] ) do |memo, p|
        memo + FileList[p + '/*.' + extension]
      end
      Rake::Cpp.expand_paths_with_root( files, @rakefile_path )
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

