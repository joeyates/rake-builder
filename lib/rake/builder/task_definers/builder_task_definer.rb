require 'logger'
require 'rake'

require 'rake/microsecond_task'
require 'rake/once_task'

include Rake::DSL

class Rake::Builder
  class BuilderTaskDefiner
    def initialize(builder)
      @builder = builder
    end

    def run
      if @builder.task_namespace
        namespace @builder.task_namespace do
          define
        end
      else
        define
      end
      define_default
    end

    private

    def define
      if @builder.target_type == :executable
        desc "Run '#{@builder.target_basename}'"
        task :run => :build do
          @builder.run
        end
      end

      desc "Compile and build '#{@builder.target_basename}'"
      task :build => [:compile, @builder.target]

      desc "Build '#{@builder.target_basename}'"
      microsecond_file @builder.target => [
        scoped_task(:environment),
        scoped_task(:compile),
        *@builder.target_prerequisites,
        *@builder.object_files,
      ] do
        @builder.build
      end

      desc "Compile all sources"
      # Only import dependencies when we're compiling
      # otherwise makedepend gets run on e.g. 'rake -T'
      once_task :compile => [
        scoped_task(:environment),
        @builder.makedepend_file,
        scoped_task(:load_makedepend),
        *@builder.object_files,
      ]

      @builder.source_files.each do |source|
        file source
        object = @builder.object_path(source)
        @builder.generated_files << object
        define_compile_task(source, object)
      end

      # Re-implement :clean locally for project and within namespace
      # Standard :clean is a singleton
      desc "Remove temporary files"
      task :clean do
        @builder.clean
      end

      desc "Install '#{@builder.target_basename}' in '#{@builder.install_path}'"
      task :install, [] => [scoped_task(:build)] do
        @builder.install
      end

      desc "Uninstall '#{@builder.target_basename}' from '#{@builder.install_path}'"
      task :uninstall, [] => [] do
        @builder.uninstall
      end

      # TODO: Does this need to be microsecond?
      microsecond_directory @builder.objects_path

      file @builder.local_config_file do
        @builder.create_local_config
      end

      once_task :load_local_config => @builder.local_config_file do
        @builder.load_local_config
      end

      once_task :missing_headers => [*@builder.generated_headers] do
        @builder.ensure_headers
      end

      microsecond_file @builder.makedepend_file => [
        scoped_task(:load_local_config),
        scoped_task(:missing_headers),
        @builder.objects_path,
        *@builder.source_files,
      ] do
        @builder.create_makedepend_file
      end

      # Reimplemented mkdepend file loading to make objects depend on
      # sources with the correct paths:
      # the standard rake mkdepend loader doesn't do what we want,
      # as it assumes files will be compiled in their own directory.
      once_task :load_makedepend => @builder.makedepend_file do
        object_header_dependencies = @builder.load_makedepend
        object_header_dependencies.each do |object_file, headers|
          headers.each { |h| file h }
          object_file_task = Rake.application[object_file]
          object_file_task.enhance headers
        end
      end

      desc "Create a '#{@builder.makefile_name}' to build the project"
      file "#{@builder.makefile_name}" => [
        @builder.makedepend_file,
        scoped_task(:load_makedepend)
      ] do
        Rake::Builder::Presenters::Makefile::BuilderPresenter.new(@builder).save
      end

      once_task :environment do
        @builder.logger.level = ::Logger::DEBUG if ENV['DEBUG']
      end
    end

    def define_default
      name = scoped_task(@builder.default_task)
      desc "Equivalent to 'rake #{name}'"
      if @builder.task_namespace
        task @builder.task_namespace => [name]
      else
        task :default => [name]
      end
    end

    def define_compile_task(source, object)
      file object => [source] do
        @builder.compile(source, object)
      end
    end

    def scoped_task(task)
      if @builder.task_namespace
        "#{@builder.task_namespace}:#{task}"
      else
        task
      end
    end
  end
end

