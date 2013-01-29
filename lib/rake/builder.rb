require 'logger'
require 'rake'

require 'rake/builder/autoconf/version'
require 'rake/builder/configure_ac'
require 'rake/builder/error'
require 'rake/builder/installer'
require 'rake/builder/local_config'
require 'rake/builder/logger/formatter'
require 'rake/builder/presenters/makefile/builder_presenter'
require 'rake/builder/presenters/makefile_am/builder_presenter'
require 'rake/builder/presenters/makefile_am/builder_collection_presenter'
require 'rake/builder/task_definers/builder_task_definer'
require 'rake/builder/task_definers/builder_collection_task_definer'
require 'rake/path'
require 'rake/microsecond_task'
require 'rake/once_task'
require 'compiler'

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
    TARGET_TYPES = [:executable, :static_library, :shared_library]

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

    # Directories/file globs to search for header files to be installed with libraries.
    # When static libraries are installed,
    # headers are installed too.
    # During installation, the destination path is:
    #   /usr/local/include + the relative path
    # This 'relative path' is calculated as follows:
    # 1. Any files named in installable_headers are installed directly under /usr/local/include
    # 2. The contents of any directory named in installable_headers are also installed directly under /usr/local/include
    # 3. Files found by glob have the fixed part of the glob removed and
    #  the relative path calculated:
    # E.g. files found with './include/**/*' will have './include' removed to calculate the
    #  relative path.
    # So, ./include/my_lib/foo.h' produces a relative path of 'my_lib'
    # so the file will be installed as '/usr/local/include/my_lib/foo.h'
    attr_accessor :installable_headers

    def header_search_paths
      warn 'Deprecation notice: Rake::Builder#header_search_paths has been replaced by Rake::Builder#installable_headers'
      installable_headers
    end

    def header_search_paths=(paths)
      warn 'Deprecation notice: Rake::Builder#header_search_paths has been replaced by Rake::Builder#installable_headers'
      installable_headers = paths
    end

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

    # All Rake::Builder instances that get defined
    # This allows us to create scripts for configure
    @instances = []

    def self.instances
      @instances
    end

    def self.create_autoconf(project_title, version, source_file)
      raise "Please supply a project_title parameter" if project_title.nil?
      version = Rake::Builder::Autoconf::Version.new(version).decide
      if File.exist?('configure.ac')
        raise "The file 'configure.ac' already exists"
      end
      if File.exist?('Makefile.am')
        raise "The file 'Makefile.am' already exists"
      end
      ConfigureAc.new(project_title, version, source_file).save
      Presenters::MakefileAm::BuilderCollectionPresenter.new(instances).save
    end

    Rake::Builder::BuilderCollectionTaskDefiner.new.run

    def initialize(&block)
      raise 'No block given' if block.nil?
      save_rakefile_info(block)
      set_defaults
      block.call(self)
      configure
      BuilderTaskDefiner.new(self).run
      self.class.instances << self
    end

    ################################################
    # main actions

    def build
      logger.debug "Building '#{target}'"
      File.unlink(target) if File.exist?(target)
      build_commands.each do |command|
        stdout, stderr = shell(command)
        raise BuildFailure.new("Error: command '#{command}' failed: #{stderr} #{stdout}") if not $?.success?
      end
      raise BuildFailure.new("'#{target}' not created") if not File.exist?(target)
    end

    def run
      old_dir = Dir.pwd
      Dir.chdir rakefile_path
      command = File.join('.', target)
      begin
        output, error = shell(command, ::Logger::INFO)
        $stdout.print output
        $stderr.print error
        raise Exception.new("Running #{command} failed with status #{$?.exitstatus}") if not $?.success?
      ensure
        Dir.chdir old_dir
      end
    end

    def clean
      generated_files.each do |file|
        File.unlink(file) if File.exist?(file)
      end
    end

    def install
      destination = File.join(install_path, target_basename)
      Rake::Builder::Installer.new.install target, destination
      install_headers if target_type == :static_library
    end

    def uninstall
      destination = File.join(install_path, target_basename)
      Rake::Builder::Installer.new.uninstall destination
    end

    ################################################
    # helpers invoked by tasks

    def create_makedepend_file
      logger.debug 'Creating makedepend file'
      system('which makedepend >/dev/null')
      raise 'makedepend not found' unless $?.success?
      command = "makedepend -f- -- #{include_path} -- #{file_list(source_files)} 2>/dev/null > #{makedepend_file}"
      shell command
    end

    def load_makedepend
      content = File.read(makedepend_file)
      # Replace old-style files with full paths
      if content =~ %r(^/)
        create_makedepend_file
        return load_makedepend
      end

      # makedepend assumes each .o files will be in the same path as its source
      real_object_path = source_files.inject({}) do |a, source|
        source_path_object = source.gsub('.' + source_file_extension, '.o')
        correct_path_object = object_path(source)
        a[source_path_object] = correct_path_object
        a
      end

      object_header_dependencies = Hash.new { |h, v| h[v] = [] }
      content.each_line do |line|
        next if line !~ /:\s/
        source_path_object = $`
        header_files = $'.chomp
        object_path_name = real_object_path[source_path_object]
        object_header_dependencies[object_path_name] += header_files.split(' ')
      end

      object_header_dependencies
    end

    def generated_headers
      []
    end

    # Raises an error if there are missing headers
    def ensure_headers
      missing = missing_headers
      return if missing.size == 0

      message = "Compilation cannot proceed as the following header files are missing:\n" + missing.join("\n") 
      raise Error.new(message)
    end

    def load_local_config
      config = Rake::Builder::LocalConfig.new(local_config)
      config.load
      @include_paths       += config.include_paths
      @compilation_options += config.compilation_options
    end

    def create_local_config
      logger.debug "Creating file '#{local_config}'"
      added_includes = compiler_data.include_paths(missing_headers)
      config = Rake::Builder::LocalConfig.new(local_config)
      config.include_paths = added_includes
      config.save
    end

    def compile(source, object)
      logger.add(::Logger::DEBUG, "Compiling '#{source}'")
      command = "#{compiler} -c #{compiler_flags} -o #{object} #{source}"
      stdout, stderr = shell(command)
      raise BuildFailure.new("Error: command '#{command}' failed: #{stderr} #{stdout}") if not $?.success?
    end

    ################################################
    # public attributes

    def is_library?
      [:static_library, :shared_library].include?(target_type)
    end

    def target_basename
      File.basename(@target)
    end

    def label
      target.gsub(%r(\.), '_')
    end

    # Source files found in source_search_paths
    def source_files
      return @source_files if @source_files

      old_dir = Dir.pwd
      Dir.chdir @rakefile_path
      @source_files = Rake::Path.find_files(@source_search_paths, source_file_extension).uniq.sort
      Dir.chdir old_dir
      @source_files
    end

    def object_files
      source_files.map { |file| object_path(file) }
    end

    def object_path(source_path_name)
      o_name = File.basename(source_path_name).gsub('.' + source_file_extension, '.o')
      File.join(objects_path, o_name)
    end

    def compiler_flags
      flags = include_path
      options = compilation_options.join(' ')
      flags << ' ' + options             if options != ''
      flags << ' ' + architecture_option if RUBY_PLATFORM =~ /darwin/i
      flags
    end

    def link_flags
      flags = [@linker_options, library_paths_list, library_dependencies_list]
      flags << architecture_option if RUBY_PLATFORM =~ /darwin/i
      flags.join(" ")
    end

    def library_dependencies_list
      @library_dependencies.map { |lib| "-l#{lib}" }.join(' ')
    end

    def makefile_name
      extension = if ! task_namespace.nil? && ! task_namespace.to_s.empty?
                    '.' + task_namespace.to_s
                  else
                    ''
                  end
      "Makefile#{extension}"
    end

    private

    # Lists headers referenced by the project's files or includes
    # that can not be found on in any of the include paths
    def missing_headers
      return @missing_headers if @missing_headers
      default_includes = @compiler_data.default_include_paths(@programming_language)
      all_includes     = default_includes + @include_paths
      @missing_headers = @compiler_data.missing_headers(all_includes, source_files)
    end

    def set_defaults
      @architecture          = 'i386'
      @compiler_data         = Compiler::Base.for(:gcc)
      @logger                = ::Logger.new(STDOUT)
      @logger.level          = ::Logger::UNKNOWN
      @logger.formatter      = Rake::Builder::Logger::Formatter.new
      @programming_language  = 'c++'
      @header_file_extension = 'h'
      @objects_path          = '.'
      @library_paths         = []
      @library_dependencies  = []
      @target_prerequisites  = []
      @source_search_paths   = ['.']
      @target                = './a.out'
      @generated_files       = []
      @compilation_options   = []
      @include_paths         = ['./include']
      @installable_headers   ||= []
    end

    def configure
      @compilation_options   += [architecture_option] if RUBY_PLATFORM =~ /apple/i
      @compilation_options.uniq!

      @programming_language = @programming_language.to_s.downcase
      raise Error.new("Don't know how to build '#{@programming_language}' programs", task_namespace) if KNOWN_LANGUAGES[@programming_language].nil?
      @compiler              ||= KNOWN_LANGUAGES[@programming_language][:compiler]
      @linker                ||= KNOWN_LANGUAGES[@programming_language][:linker]
      @ar                    ||= KNOWN_LANGUAGES[@programming_language][:ar]
      @ranlib                ||= KNOWN_LANGUAGES[@programming_language][:ranlib]
      @source_file_extension ||= KNOWN_LANGUAGES[@programming_language][:source_file_extension]


      raise Error.new("The target name cannot be nil", task_namespace)             if @target.nil?
      raise Error.new("The target name cannot be an empty string", task_namespace) if @target == ''

      @target_type           ||= to_target_type(@target)
      raise Error.new("Building #{@target_type} targets is not supported", task_namespace) if ! TARGET_TYPES.include?(@target_type)
      @generated_files << @target

      @install_path          ||= default_install_path(@target_type)

      @linker_options        ||= ''

      @default_task          ||= :build
      @target_prerequisites  << @rakefile
      @local_config          = '.rake-builder'

      @makedepend_file       = @objects_path + '/.' + target_basename + '.depend.mf'
      @generated_files << @makedepend_file

      raise Error.new("No source files found", task_namespace) if source_files.size == 0
    end

    def to_target_type(target)
      case
      when target.end_with?('.a')
        :static_library
      when target.end_with?('.so')
        :shared_library
      else
        :executable
      end
    end

    # Compiling and linking parameters

    def include_path
      @include_paths.map { |p| "-I#{p}" }.join(' ')
    end

    def architecture_option
      "-arch #{@architecture}"
    end

    # Paths

    def save_rakefile_info(block)
      if RUBY_VERSION < '1.9'
        # Hack the path from the block String representation
        @rakefile = block.to_s.match(/@([^\:]+):/)[1]
      else
        @rakefile = block.source_location[0]
      end
      @rakefile      = File.expand_path(@rakefile)
      @rakefile_path = File.dirname(@rakefile)
    end

    def default_install_path(target_type)
      case target_type
      when :executable
        '/usr/local/bin'
      else
        '/usr/local/lib'
      end
    end

    # Files

    # Lists of files

    def file_list(files)
      files.join(' ')
    end
    
    def library_paths_list
      @library_paths.map { | path | "-L#{path}" }.join(" ")
    end

    def install_headers
      # TODO: make install_headers_path a configuration option
      install_headers_path = '/usr/local/include'

      installer = Rake::Builder::Installer.new
      project_headers.each do |installable_header|
        destination_path = File.join(install_headers_path, installable_header[:relative_path])
        begin
          `mkdir -p '#{destination_path}'`
        rescue Errno::EACCES => e
          raise Error.new("Permission denied to created directory '#{destination_path}'", task_namespace)
        end
        installer.install installable_header[:source_file], destination_path
      end
    end

    def project_headers
      @installable_headers.reduce([]) do |memo, search|
        case
        when search.start_with?('/'), search.start_with?('..')
          # Skip paths that are not inside the project
        when File.file?(search)
          memo << {:source_file => search, :relative_path => ''}
        when File.directory?(search)
          FileList[search + '/*.' + @header_file_extension].each do |pathname|
            memo << {:source_file => pathname, :relative_path => ''}
          end
        when search.match(/[\*\?]/)
          non_glob_part = search[/^([^\*\?]*\/)/, 1]
          base_path     = File.expand_path(non_glob_part, rakefile_path)
          FileList[search].each do |pathname|
            full_path = File.expand_path(pathname, rakefile_path)
            directory = File.dirname(full_path)
            relative  = File.relative_path(base_path, directory)
            memo << {:source_file => pathname, :relative_path => relative}
          end
        else
          $stderr.puts "Bad search path: '#{search}'"
        end
        memo
      end
    end

    def build_commands
      case target_type
      when :executable
        ["#{linker} -o #{target} #{file_list(object_files)} #{link_flags}"]
      when :static_library
        [
          "#{ar} -cq #{target} #{file_list(object_files)}",
          "#{ranlib} #{target}",
        ]
      when :shared_library
        ["#{linker} -shared -o #{target} #{file_list(object_files)} #{link_flags}"]
      else
        # TODO: raise an error
      end
    end

    def shell(command, log_level = ::Logger::DEBUG)
      @logger.add(log_level, command)
      originals        = $stdout, $stderr
      stdout, stderr   = StringIO.new, StringIO.new
      $stdout, $stderr = stdout, stderr
      system command, {:out => :out, :err => :err}
      $stdout, $stderr = *originals
      [stdout.string, stderr.string]
    end
  end
end

