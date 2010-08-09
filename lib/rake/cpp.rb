require 'rubygems' if RUBY_VERSION < '1.9'
require 'logger'
require 'rake'
require 'rake/tasklib'
require 'rake/loaders/makefile'

module Rake

  class Cpp < TaskLib

    module VERSION #:nodoc:
      MAJOR = 0
      MINOR = 0
      TINY  = 1
 
      STRING = [ MAJOR, MINOR, TINY ].join('.')
    end

    @@logger       = Logger.new( STDOUT )
    @@logger.level = Logger::WARN

    def self.logger
      @@logger
    end

    TARGET_TYPES = [ :executable, :static_library, :shared_library ]

    # (Optional) namespace for tasks
    attr_accessor :task_namespace

    # Name of the default task
    attr_accessor :default

    # Tasks which :build depends upon
    attr_accessor :prerequesites

    # Output type, currently: :executable, :static_library, :shared_library
    attr_accessor :target_type

    # Directories containing project source files
    attr_accessor :source_search_paths

    # Extension of source files
    attr_accessor :source_file_extension

    # Directories containing project header files
    attr_accessor :header_search_paths

    # Extension of header files
    attr_accessor :header_file_extension

    # Name of the generated file containing source - header dependencies
    attr_reader   :makedepend_file

    # Directory to be used for object files
    attr_accessor :objects_path

    # Additional include directories for compilation
    attr_accessor :include_paths

    # Name of the file to be built
    attr_accessor :target

    # Additional library directories for linking
    attr_accessor :library_paths

    # Libraries to be linked
    attr_accessor :library_dependencies

    def initialize( &block )
      set_defaults
      block.call( self )
      check_configuration
      define_tasks
      define_default
    end

    # Source files found in source_search_paths
    def source_files
      find_files( @source_search_paths, @source_file_extension )
    end

    # Header files found in header_search_paths
    def header_files
      find_files( @header_search_paths, @header_file_extension )
    end

    # Temporary files generated during compilation and linking
    def generated_files
      @clean.dup
    end

    private

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
      desc "Equivalent to 'rake #{scoped_default}'"
      if @task_namespace
        task @task_namespace => [ scoped_default ]
      else
        task :default => [ scoped_default ]
      end
    end

    def define
      file @makedepend_file => [ *project_files ] do
        @@logger.add( Logger::DEBUG, "Analysing dependencies" )
        command = "makedepend -f- -- #{include_path} -- #{file_list( source_files )} 2>/dev/null > #{@makedepend_file}"
        shell command
      end

      # Only import dependencies when we're compiling
      # otherwise makedepend gets run on e.g. 'rake -T'
      task :dependencies => @makedepend_file do |t|
        import @makedepend_file
      end

      source_files.each do |src|
        object = object_path( src )
        @clean.include( object )
        rule object => src do |t|
          @@logger.add( Logger::INFO, "Compiling '#{t.source}'" )
          shell "g++ #{cpp_flags} -c -o #{t.name} #{t.source}"
        end
      end

      file @target => :compile do |t|
        shell "rm -f #{t.name}"
        case @target_type
        when :executable
          shell "g++ #{link_flags} -o #{@target} #{file_list( object_files )}"
        when :static_library
          @@logger.add( Logger::INFO, "Builing library '#{t.name}'" )
          shell "ar -cq #{t.name} #{file_list( object_files )}"
        when :shared_library
          @@logger.add( Logger::INFO, "Builing library '#{t.name}'" )
          shell "g++ -shared -o #{t.name} #{file_list( object_files )} #{link_flags}"
        end
      end

      if @target_type == :executable
        desc "Run '#{@target}'"
        task :run => :build do
          shell absolute( @target ), Logger::INFO
        end
      end

      # Re-implement :clean locally for project and within namespace
      # Standard :clean is a singleton
      desc "Remove temporary files"
      task :clean do
        @clean.each { |f| `rm -f #{f}` }
      end

      @clean.include( @target )
      @clean.include( @makedepend_file )

      desc "Compile all sources"
      task :compile => [ :dependencies, *object_files ]

      desc "Compile and build '#{@target}'"
      task :build => @prerequesites + [ @target ]
    end

    def set_defaults
      @default               = :build
      @prerequesites         = []
      @source_search_paths   = [ '.' ]
      @header_search_paths   = [ '.' ]
      @source_file_extension = 'cpp'
      @header_file_extension = 'h'
      @objects_path          = '.'
      @include_paths         = []
      @target = 'a.out'
      @library_paths         = []
      @library_dependencies  = []
    end

    def check_configuration
      raise "No source paths specified" if @source_search_paths.length == 0

      @target_type ||= type( @target )
      raise "Building #{@target_type} targets is not supported" if ! TARGET_TYPES.include?( @target_type )

      @source_search_paths.collect!{ |p| absolute( p ) }
      @header_search_paths.collect!{ |p| absolute( p ) }
      @objects_path = absolute( @objects_path )
      @include_paths.collect!{ |p| absolute( p ) }
      @library_paths.collect!{ |p| absolute( p ) }

      @makedepend_file = @objects_path + '/.' + File::basename( @target ) + '.depend.mf'
      @clean           = Rake::FileList.new
    end

    def scoped_default
      if @task_namespace
        "#{task_namespace}:#{@default}"
      else
        @default
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
      @include_paths.map { |p| "-I#{p}" }.join( " " )
    end

    def cpp_flags
      include_path
    end

    def link_flags
      [ library_paths_list, library_dependencies_list ].join( " " )
    end

    # Paths

    def object_path( source_path_name )
      o_name = File.basename( source_path_name ).gsub( '.' + @source_file_extension, '.o' )
      @objects_path + '/' + o_name
    end

    def absolute( p )
      File.expand_path( p )
    end

    # Lists of files

    def find_files( paths, ending )
      paths.reduce( [] ) do |memo, p|
        memo + FileList[p + '/*.' + ending]
      end
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
      @library_paths.map { |l| "-L#{l}" }.join( " " )
    end
    
    def library_dependencies_list
      @library_dependencies.map { |l| "-l#{l}" }.join( " " )
    end

    def shell( command, log_level = Logger::DEBUG )
      @@logger.add( log_level, command )
      sh command
    end

  end

end
