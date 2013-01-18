require 'rake/file_task_alias'
require 'rake/local_config'

include Rake::DSL

class Rake::Builder
  class TaskDefiner
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
      once_task :environment do
        @builder.logger.level = Logger::DEBUG if ENV['DEBUG']
      end

      if @builder.target_type == :executable
        desc "Run '#{@builder.target_basename}'"
        task :run => :build do
          @builder.run
        end
      end

      desc "Compile and build '#{@builder.target_basename}'"
      Rake::FileTaskAlias.define_task(:build, @builder.target)

      desc "Build '#{@builder.target_basename}'"
      microsecond_file @builder.target => [
        scoped_task(:environment),
        scoped_task(:compile),
        *@builder.target_prerequisites
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
        *@builder.object_files
      ]

      @builder.source_files.each do |src|
        define_compile_task(src)
      end

      # TODO: Does this need to be microsecond?
      microsecond_directory @builder.objects_path

      file @builder.local_config do
        @builder.create_local_config
      end

      microsecond_file @builder.makedepend_file => [
          scoped_task(:load_local_config),
          scoped_task(:missing_headers),
          @builder.objects_path,
          *@builder.project_files
      ] do
        @builder.create_makedepend_file
      end

      once_task :load_local_config => scoped_task(@builder.local_config) do
        @builder.load_local_config
      end

      once_task :missing_headers => [*@builder.generated_headers] do
        @builder.missing_headers
      end

      # Reimplemented mkdepend file loading to make objects depend on
      # sources with the correct paths:
      # the standard rake mkdepend loader doesn't do what we want,
      # as it assumes files will be compiled in their own directory.
      task :load_makedepend => @builder.makedepend_file do
        @builder.load_makedepend
      end

      desc "List generated files (which are removed with 'rake #{scoped_task(:clean)}')"
      task :generated_files do
        puts @builder.generated_files.to_json
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

      desc "Create a '#{@builder.makefile_name}' to build the project"
      file "#{@builder.makefile_name}" => [@builder.makedepend_file, scoped_task(:load_makedepend)] do
        Rake::Builder::Presenters::Makefile::BuilderPresenter.new(@builder).save
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

    def define_compile_task(source)
      object = @builder.object_path(source)
      @builder.generated_files << object
      file object => [ source ] do |t|
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

