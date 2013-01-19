require 'json'
require 'logger'
require 'rake'
require 'rake/tasklib'

require 'rake/builder/autoconf/version'
require 'rake/builder/configure_ac'
require 'rake/builder/error'
require 'rake/builder/logger/formatter'
require 'rake/builder/presenters/makefile/builder_presenter'
require 'rake/builder/presenters/makefile_am/builder_presenter'
require 'rake/builder/presenters/makefile_am/builder_collection_presenter'
require 'rake/builder/task_definer'
require 'rake/path'
require 'rake/microsecond'
require 'rake/once_task'
require 'compiler'

include Rake::DSL

module Rake
  class Builder
    # Error indicating that the project failed to build.
    class BuildFailure < Error; end

    # The file to be built
    attr_accessor :target

    # The type of file to be built
    # One of: :executable, :static_library, :shared_library
    # If not set, this is deduced from the target.
    attr_accessor :target_type

    # The types of file that can be built
    TARGET_TYPES = [ :executable, :static_library, :shared_library ]

    # processor type: 'i386', 'x86_64', 'ppc' or 'ppc64'.
    attr_accessor :architecture

    attr_accessor :compiler_data

    # The programming language: 'c++', 'c' or 'objective-c' (default 'c++')
    # This also sets defaults for source_file_extension
    attr_accessor :programming_language

    # Programmaing languages that Rake::Builder can handle
    KNOWN_LANGUAGES = {
      'c' => {
        :source_file_extension => 'c',
        :compiler              => 'gcc',
        :linker                => 'gcc',
        :ar                    => 'ar',
        :ranlib                => 'ranlib'
      },
      'c++' => {
        :source_file_extension => 'cpp',
        :compiler              => 'g++',
        :linker                => 'g++',
        :ar                    => 'ar',
        :ranlib                => 'ranlib'
      },
      'objective-c' => {
        :source_file_extension => 'm',
        :compiler              => 'gcc',
        :linker                => 'gcc',
        :ar                    => 'ar',
        :ranlib                => 'ranlib'
      },
    }

    # The compiler that will be used
    attr_accessor :compiler

    # The linker that will be used
    attr_accessor :linker

    # Toolchain setting - ar
    attr_accessor :ar

    # Toolchain setting - ranlib
    attr_accessor :ranlib

    # Extension of source files (default 'cpp' for C++ and 'c' for C)
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

    # Directories/file globs to search for project source files
    attr_accessor :source_search_paths

    # Directories/file globs to search for header files
    # When static libraries are installed,
    # headers are installed too.
    # During installation, the destination path is:
    #   /usr/local/include + the relative path
    # This 'relative path' is calculated as follows:
    # 1. Any files named in header_search_paths are installed directly under /usr/local/include
    # 2. The contents of any directory named in header_search_paths are also installed directly under /usr/local/include
    # 3. Files found by glob have the fixed part of the glob removed and
    #  the relative path calculated:
    # E.g. files found with './include/**/*' will have './include' removed to calculate the
    #  relative path.
    # So, ./include/my_lib/foo.h' produces a relative path of 'my_lib'
    # so the file will be installed as '/usr/local/include/my_lib/foo.h'
    attr_accessor :header_search_paths

    # (Optional) namespace for tasks
    attr_accessor :task_namespace

    # Name of the default task
    attr_accessor :default_task

    # Tasks which the target file depends upon
    attr_accessor :target_prerequisites

    # Directory to be used for object files
    attr_accessor :objects_path

    # Array of extra options to pass to the compiler
    attr_accessor :compilation_options

    # Additional include directories for compilation
    attr_accessor :include_paths

    # Additional library directories for linking
    attr_accessor :library_paths

    # extra options to pass to the linker
    attr_accessor :linker_options

    # Libraries to be linked
    attr_accessor :library_dependencies

    # The directory where 'rake install' will copy the target file
    attr_accessor :install_path

    # Name of the generated file containing source - header dependencies
    attr_reader   :makedepend_file

    # The file containing local settings such as include paths
    attr_reader   :local_config

    # Temporary files generated during compilation and linking
    attr_accessor :generated_files

    # Each instance has its own logger
    attr_accessor :logger

    # All Rake::Builder instaces that get defined
    # This allows us to create scripts for configure
    @instances = []

    def self.instances
      @instances
    end

    def self.create_autoconf(project_title, version, source_file)
      raise "Please supply a project_title parameter" if project_title.nil?
      version = Rake::Builder::Version.new(version).decide
      if File.exist?('configure.ac')
        raise "The file 'configure.ac' already exists"
      end
      if File.exist?('Makefile.am')
        raise "The file 'Makefile.am' already exists"
      end
      ConfigureAc.new(project_title, version, source_file).save
      Presenters::MakefileAm::BuilderCollectionPresenter.new(instances).save
    end
 
    desc "Create input files for configure script creation"
    task :autoconf, [:project_title, :version] => [] do |task, args|
      source = Rake::Path.relative_path(instances[0].source_files[0], instances[0].rakefile_path)
      create_autoconf(args.project_title, args.version, source)
    end

    def initialize(&block)
      save_rakefile_info(block)
      set_defaults
      block.call(self)
      configure
      TaskDefiner.new(self).run
      self.class.instances << self
    end

    def run
      command = "cd #{rakefile_path} && #{target}"
      puts shell(command, Logger::INFO)
    end

    def build
      system "rm -f #{target}"
      build_commands.each do |command|
        stdout, stderr = shell(command)
        raise BuildFailure.new("Error: command '#{command}' failed: #{stderr} #{stdout}") if not $?.success?
      end
      raise BuildFailure.new("'#{target}' not created") if not File.exist?(target)
    end

    def create_local_config
      logger.add(Logger::DEBUG, "Creating file '#{local_config }'")
      added_includes = compiler_data.include_paths(missing_headers)
      config = Rake::LocalConfig.new(local_config)
      config.include_paths = added_includes
      config.save
    end

    def create_makedepend_file
      system('which makedepend >/dev/null')
      raise 'makedepend not found' unless $?.success?
      logger.add(Logger::DEBUG, "Analysing dependencies")
      command = "makedepend -f- -- #{include_path} -- #{file_list(source_files)} 2>/dev/null > #{makedepend_file}"
      shell command
    end

    def load_local_config
      config = Rake::LocalConfig.new(local_config)
      config.load
      @include_paths       += Rake::Path.expand_all_with_root(config.include_paths, rakefile_path)
      @compilation_options += config.compilation_options
    end

    def load_makedepend
      object_to_source = source_files.inject({}) do |memo, source|
        mapped_object = source.gsub('.' + source_file_extension, '.o')
        memo[mapped_object] = source
        memo
      end

      object_header_dependencies = Hash.new { |h, v| h[v] = [] }
      File.open(makedepend_file).each_line do |line|
        next if line !~ /:\s/
        mapped_object_file = $`
        header_files = $'.chomp
        # TODO: Why does it work,
        # if I make the object (not the source) depend on the header?
        source_file = object_to_source[mapped_object_file]
        object_file = object_path(source_file)
        object_header_dependencies[object_file] += header_files.split(' ')
      end
      object_header_dependencies
    end

    def clean
      generated_files.each do |file|
        system "rm -f #{file}"
      end
    end

    def install
      destination = File.join(install_path, target_basename)
      install_file(target, destination)
      install_headers if target_type == :static_library
    end

    def uninstall
      destination = File.join(install_path, target_basename)
      if not File.exist?(destination)
        logger.add(Logger::INFO, "The file '#{destination}' does not exist")
        return
      end
      begin
        shell "rm '#{destination}'", Logger::INFO
      rescue Errno::EACCES => e
        raise Error.new("You do not have permission to uninstall '#{destination}'\nTry re-running the command with 'sudo'", task_namespace)
      end
    end

    def compile(source, object)
      logger.add(Logger::DEBUG, "Compiling '#{source}'")
      command = "#{compiler} -c #{compiler_flags} -o #{object} #{source}"
      stdout, stderr = shell(command)
      raise BuildFailure.new("Error: command '#{command}' failed: #{stderr} #{stdout}") if not $?.success?
    end

    # Source files found in source_search_paths
    def source_files
      return @source_files if @source_files
      @source_files = find_files( @source_search_paths, @source_file_extension ).uniq.sort
    end

    # Header files found in header_search_paths
    def header_files
      return @header_files if @header_files
      @header_files = find_files( @header_search_paths, @header_file_extension ).uniq
    end

    def is_library?
      [:static_library, :shared_library].include?(target_type)
    end

    def primary_name
      Rake::Path.relative_path(target, rakefile_path, :initial_dot_slash => false)
    end

    def label
      primary_name.gsub(%r(\.), '_')
    end

    def source_paths
      source_files.map{ |file| Rake::Path.relative_path(file, rakefile_path) }
    end

    def object_files
      source_files.map { |file| object_path(file) }
    end

    def object_path(source_path_name)
      o_name = File.basename(source_path_name).gsub('.' + source_file_extension, '.o')
      Rake::Path.expand_with_root(o_name, objects_path)
    end

    def compiler_flags
      flags = include_path
      options = compilation_options.join(' ')
      flags << ' ' + options             if options != ''
      flags << ' ' + architecture_option if RUBY_PLATFORM =~ /darwin/i
      flags
    end

    def library_dependencies_list
      @library_dependencies.map { |lib| "-l#{ lib }"}.join('')
    end

    def target_basename
      File.basename(@target)
    end

    def makefile_name
      extension = if ! task_namespace.nil? && ! task_namespace.to_s.empty?
                    '.' + task_namespace.to_s
                  else
                    ''
                  end
      "Makefile#{ extension }"
    end

    def project_files
      source_files + header_files
    end

    def generated_headers
      []
    end

    # Discovery

    def ensure_headers
      missing = missing_headers
      return if missing.size == 0

      message = "Compilation cannot proceed as the following header files are missing:\n" + missing.join("\n") 
      raise Error.new(message)
    end

    private

    def missing_headers
      return @missing_headers if @missing_headers
      default_includes = @compiler_data.default_include_paths( @programming_language )
      all_includes     = default_includes + @include_paths
      @missing_headers = @compiler_data.missing_headers( all_includes, source_files )
    end

    def set_defaults
      @architecture          = 'i386'
      @compiler_data         = Compiler::Base.for(:gcc)
      @logger                = Logger.new(STDOUT)
      @logger.level          = Logger::UNKNOWN
      @logger.formatter      = Formatter.new
      @programming_language  = 'c++'
      @header_file_extension = 'h'
      @objects_path          = @rakefile_path.dup
      @library_paths         = []
      @library_dependencies  = []
      @target_prerequisites  = []
      @source_search_paths   = [@rakefile_path.dup]
      @header_search_paths   = [@rakefile_path.dup]
      @target                = 'a.out'
      @generated_files       = []
      @compilation_options   = []
      @include_paths         = []
    end

    def configure
      @compilation_options   += [architecture_option] if RUBY_PLATFORM =~ /apple/i
      @compilation_options.uniq!

      @programming_language = @programming_language.to_s.downcase
      raise Error.new( "Don't know how to build '#{ @programming_language }' programs", task_namespace ) if KNOWN_LANGUAGES[ @programming_language ].nil?
      @compiler              ||= KNOWN_LANGUAGES[ @programming_language ][ :compiler ]
      @linker                ||= KNOWN_LANGUAGES[ @programming_language ][ :linker ]
      @ar                    ||= KNOWN_LANGUAGES[ @programming_language ][ :ar ]
      @ranlib                ||= KNOWN_LANGUAGES[ @programming_language ][ :ranlib ]
      @source_file_extension ||= KNOWN_LANGUAGES[ @programming_language ][ :source_file_extension ]

      @source_search_paths   = Rake::Path.expand_all_with_root( @source_search_paths, @rakefile_path )
      @header_search_paths   = Rake::Path.expand_all_with_root( @header_search_paths, @rakefile_path )
      @library_paths         = Rake::Path.expand_all_with_root( @library_paths, @rakefile_path )

      raise Error.new( "The target name cannot be nil", task_namespace )             if @target.nil?
      raise Error.new( "The target name cannot be an empty string", task_namespace ) if @target == ''
      @objects_path          = Rake::Path.expand_with_root( @objects_path, @rakefile_path )

      @target                = File.expand_path( @target, @rakefile_path )
      @target_type           ||= to_target_type( @target )
      raise Error.new( "Building #{ @target_type } targets is not supported", task_namespace ) if ! TARGET_TYPES.include?( @target_type )
      @generated_files << @target

      @install_path          ||= default_install_path( @target_type )

      @linker_options        ||= ''
      @include_paths         += []
      @include_paths         = Rake::Path.expand_all_with_root( @include_paths.uniq, @rakefile_path )
      @generated_files       = Rake::Path.expand_all_with_root( @generated_files, @rakefile_path )

      @default_task          ||= :build
      @target_prerequisites  << @rakefile
      @local_config          = Rake::Path.expand_with_root( '.rake-builder', @rakefile_path )

      @makedepend_file       = @objects_path + '/.' + target_basename + '.depend.mf'
      @generated_files << @makedepend_file

      raise Error.new( "No source files found", task_namespace ) if source_files.length == 0
    end

    def to_target_type(target)
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
      paths = @include_paths.map{ | file | Rake::Path.relative_path( file, rakefile_path) }
      paths.map { |p| "-I#{ p }" }.join( ' ' )
    end

    def architecture_option
      "-arch #{ @architecture }"
    end

    def link_flags
      flags = [ @linker_options, library_paths_list, library_dependencies_list ]
      flags << architecture_option if RUBY_PLATFORM =~ /darwin/i
      flags.join( " " )
    end

    # Paths

    def save_rakefile_info( block )
      if RUBY_VERSION < '1.9'
        # Hack the path from the block String representation
        @rakefile = block.to_s.match( /@([^\:]+):/ )[ 1 ]
      else
        @rakefile = block.source_location[ 0 ]
      end
      @rakefile      = File.expand_path( @rakefile )
      @rakefile_path = File.dirname( @rakefile )
    end

    def default_install_path( target_type )
      case target_type
      when :executable
        '/usr/local/bin'
      else
        '/usr/local/lib'
      end
    end

    def group_files_by_path( files )
      files.group_by do | f |
        m = f.match( /(.*?)?\/?([^\/]+)$/ )
        m[ 1 ]
      end
    end

    # Files

    # Lists of files

    def file_list(files)
      files.join(' ')
    end

    def find_files( paths, extension )
      files = Rake::Path.find_files( paths, extension )
      Rake::Path.expand_all_with_root( files, @rakefile_path )
    end
    
    def library_paths_list
      @library_paths.map { | path | "-L#{ path }" }.join( " " )
    end

    def install_headers
      # TODO: make install_headers_path a configuration option
      install_headers_path = '/usr/local/include'

      project_headers.each do | installable_header |
        destination_path = File.join( install_headers_path, installable_header[ :relative_path ] )
        begin
          `mkdir -p '#{ destination_path }'`
        rescue Errno::EACCES => e
          raise Error.new( "Permission denied to created directory '#{ destination_path }'", task_namespace )
        end
        install_file( installable_header[ :source_file ], destination_path )
      end
    end

    def project_headers
      @header_search_paths.reduce( [] ) do | memo, search |
        non_glob_search = ( search.match( /^([^\*\?]*)/ ) )[ 1 ]
        case
        when ( non_glob_search !~ /#{ @rakefile_path }/ )
          # Skip paths that are not inside the project
        when File.file?( search )
          full_path = Rake::Path.expand_with_root( search, @rakefile_path )
          memo << { :source_file => search, :relative_path => '' }
        when File.directory?( search )
          FileList[ search + '/*.' + @header_file_extension ].each do | pathname |
            full_path = Rake::Path.expand_with_root( pathname, @rakefile_path )
            memo << { :source_file => pathname, :relative_path => '' }
          end
        when ( search =~ /[\*\?]/ )
          FileList[ search ].each do | pathname |
            full_path = Rake::Path.expand_with_root( pathname, @rakefile_path )
            directory = File.dirname( full_path )
            relative  = Rake::Path.relative_path( directory, non_glob_search )
            memo << { :source_file => pathname, :relative_path => relative }
          end
        else
          $stderr.puts "Bad search path: '${ search }'"
        end
        memo
      end
    end

    def build_commands
      case target_type
      when :executable
        [ "#{ linker } -o #{ target } #{ file_list( object_files ) } #{ link_flags }" ]
      when :static_library
        [ "#{ ar } -cq #{ target } #{ file_list( object_files ) }",
          "#{ ranlib } #{ target }" ]
      when :shared_library
        [ "#{ linker } -shared -o #{ target } #{ file_list( object_files ) } #{ link_flags }" ]
      else
        # TODO: raise an error
      end
    end

    def install_file(source_pathname, destination_path)
      begin
        shell "cp '#{ source_pathname }' '#{ destination_path }'", Logger::INFO
      rescue Errno::EACCES => e
        source_filename = File.basename( source_pathname ) rescue '????'
        raise Error.new( "You do not have permission to install '#{ source_filename }' to '#{ destination_path }'\nTry\n $ sudo rake install", task_namespace )
      end
    end

    def shell(command, log_level = Logger::DEBUG)
      @logger.add(log_level, command)
      originals        = $stdout, $stderr
      stdout, stderr   = StringIO.new, StringIO.new
      $stdout, $stderr = stdout, stderr
      system command, {:out => :out, :err => :err}
      $stdout, $stderr = *originals
      [stdout.read, stderr.read]
    end
  end
end

