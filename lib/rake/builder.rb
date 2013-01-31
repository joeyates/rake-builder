require 'logger'
require 'rake'

require 'rake/builder/autoconf/version'
require 'rake/builder/configuration'
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

    attr_accessor :config

    # Name of the generated file containing source - header dependencies
    attr_reader   :makedepend_file

    # The file containing local settings such as include paths
    attr_reader   :local_config_file

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
      self.config = Configuration.new(block)
      set_defaults
      configure
      BuilderTaskDefiner.new(self).run
      self.class.instances << self
    end

    ################################################
    # main actions

    def build
      logger.debug "Building '#{target}'"
      File.unlink(config.target) if File.exist?(config.target)
      build_commands.each do |command|
        stdout, stderr = shell(command)
        raise BuildFailure.new("Error: command '#{command}' failed: #{stderr} #{stdout}") if not $?.success?
      end
      raise BuildFailure.new("'#{config.target}' not created") if not File.exist?(config.target)
    end

    def run
      old_dir = Dir.pwd
      Dir.chdir config.rakefile_path
      command = File.join('.', config.target)
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
      destination = File.join(config.install_path, target_basename)
      Rake::Builder::Installer.new.install config.target, destination
      install_headers if config.target_type == :static_library
    end

    def uninstall
      destination = File.join(config.install_path, target_basename)
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
        source_path_object = source.gsub('.' + config.source_file_extension, '.o')
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
      local = Rake::Builder::LocalConfig.new(local_config_file)
      local.load
      config.include_paths       += local.include_paths
      config.compilation_options += local.compilation_options
    end

    def create_local_config
      logger.debug "Creating file '#{local_config_file}'"
      added_includes = @compiler_data.include_paths(missing_headers)
      local = Rake::Builder::LocalConfig.new(local_config_file)
      local.include_paths = added_includes
      local.save
    end

    def compile(source, object)
      logger.add(::Logger::DEBUG, "Compiling '#{source}'")
      command = "#{config.compiler} -c #{compiler_flags} -o #{object} #{source}"
      stdout, stderr = shell(command)
      raise BuildFailure.new("Error: command '#{command}' failed: #{stderr} #{stdout}") if not $?.success?
    end

    ################################################
    # public attributes

    # delegated to config

    def target
      config.target
    end

    def target_type
      config.target_type
    end

    def install_path
      config.install_path
    end

    def objects_path
      config.objects_path
    end

    def default_task
      config.default_task
    end

    def task_namespace
      config.task_namespace
    end

    def target_prerequisites
      config.target_prerequisites
    end

    # other

    def is_library?
      [:static_library, :shared_library].include?(config.target_type)
    end

    def target_basename
      File.basename(config.target)
    end

    def label
      config.target.gsub(%r(\.), '_')
    end

    # Source files found in source_search_paths
    def source_files
      return @source_files if @source_files

      old_dir = Dir.pwd
      Dir.chdir config.rakefile_path
      @source_files = Rake::Path.find_files(config.source_search_paths, config.source_file_extension).uniq.sort
      Dir.chdir old_dir
      @source_files
    end

    def object_files
      source_files.map { |file| object_path(file) }
    end

    def object_path(source_path_name)
      o_name = File.basename(source_path_name).gsub('.' + config.source_file_extension, '.o')
      File.join(config.objects_path, o_name)
    end

    def compiler_flags
      flags = include_path
      options = config.compilation_options.join(' ')
      flags << ' ' + options             if options != ''
      flags << ' ' + architecture_option if RUBY_PLATFORM =~ /darwin/i
      flags
    end

    def link_flags
      flags = [config.linker_options, library_paths_list, library_dependencies_list]
      flags << architecture_option if RUBY_PLATFORM =~ /darwin/i
      flags.join(" ")
    end

    def library_dependencies_list
      config.library_dependencies.map { |lib| "-l#{lib}" }.join(' ')
    end

    def makefile_name
      extension = if ! config.task_namespace.nil? && ! config.task_namespace.to_s.empty?
                    '.' + config.task_namespace.to_s
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
      default_includes = @compiler_data.default_include_paths(config.programming_language)
      all_includes     = default_includes + config.include_paths
      @missing_headers = @compiler_data.missing_headers(all_includes, source_files)
    end

    def set_defaults
      @compiler_data         = Compiler::Base.for(:gcc)
      @logger                = ::Logger.new(STDOUT)
      @logger.level          = ::Logger::UNKNOWN
      @logger.formatter      = Rake::Builder::Logger::Formatter.new
      @generated_files       = []
      @local_config_file     = '.rake-builder'
    end

    def configure
      @makedepend_file       = config.objects_path + '/.' + target_basename + '.depend.mf'
      @generated_files << config.target
      @generated_files << @makedepend_file

      raise Error.new("No source files found", config.task_namespace) if source_files.size == 0
    end

    # Compiling and linking parameters

    def include_path
      config.include_paths.map { |p| "-I#{p}" }.join(' ')
    end

    def architecture_option
      "-arch #{config.architecture}"
    end

    # Lists of files

    def file_list(files)
      files.join(' ')
    end
    
    def library_paths_list
      config.library_paths.map { | path | "-L#{path}" }.join(" ")
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
          raise Error.new("Permission denied to created directory '#{destination_path}'", config.task_namespace)
        end
        installer.install installable_header[:source_file], destination_path
      end
    end

    def project_headers
      config.installable_headers.reduce([]) do |memo, search|
        case
        when search.start_with?('/'), search.start_with?('..')
          # Skip paths that are not inside the project
        when File.file?(search)
          memo << {:source_file => search, :relative_path => ''}
        when File.directory?(search)
          FileList[search + '/*.' + config.header_file_extension].each do |pathname|
            memo << {:source_file => pathname, :relative_path => ''}
          end
        when search.match(/[\*\?]/)
          non_glob_part = search[/^([^\*\?]*\/)/, 1]
          base_path     = File.expand_path(non_glob_part, config.rakefile_path)
          FileList[search].each do |pathname|
            full_path = File.expand_path(pathname, config.rakefile_path)
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
      case config.target_type
      when :executable
        ["#{config.linker} -o #{config.target} #{file_list(object_files)} #{link_flags}"]
      when :static_library
        [
          "#{config.ar} -cq #{config.target} #{file_list(object_files)}",
          "#{config.ranlib} #{config.target}",
        ]
      when :shared_library
        ["#{config.linker} -shared -o #{config.target} #{file_list(object_files)} #{link_flags}"]
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

