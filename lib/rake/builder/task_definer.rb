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
    end

    private

    def define
      once_task :environment do
        @builder.logger.level = Logger::DEBUG if ENV['DEBUG']
      end

      if @builder.target_type == :executable
        desc "Run '#{@builder.target_basename}'"
        task :run => :build do
          command = "cd #{@builder.rakefile_path} && #{@builder.target}"
          puts system(command)
          #puts shell(command, Logger::INFO)
        end
      end

      desc "Compile and build '#{@builder.target_basename}'"
      Rake::FileTaskAlias.define_task(:build, @builder.target)

      desc "Build '#{@builder.target_basename}'"
      microsecond_file @builder.target => [
        @builder.scoped_task(:environment),
        @builder.scoped_task(:compile),
        *@builder.target_prerequisites
      ] do
        system "rm -f #{@builder.target}"
        build_commands.each do |command|
          system(command)
          raise BuildFailure.new("Error: command '#{command}' failed") if not $?.success?
          #stdout, stderr = shell(command)
          #raise BuildFailure.new("Error: command '#{command}' failed: #{stderr} #{stdout}") if not $?.success?
        end
        raise BuildFailure.new("'#{@builder.target}' not created") if not File.exist?(@builder.target)
      end

      desc "Compile all sources"
      # Only import dependencies when we're compiling
      # otherwise makedepend gets run on e.g. 'rake -T'
      once_task :compile => [
        @builder.scoped_task(:environment),
        @builder.makedepend_file,
        @builder.scoped_task(:load_makedepend),
        *object_files
      ]

      @builder.source_files.each do |src|
        define_compile_task(src)
      end

      microsecond_directory @builder.objects_path

      file @builder.scoped_task(@builder.local_config) do
        @builder.logger.add( Logger::DEBUG, "Creating file '#{ @builder.local_config }'" )
        added_includes = @builder.compiler_data.include_paths( @builder.missing_headers )
        config = Rake::LocalConfig.new( @builder.local_config )
        config.include_paths = added_includes
        config.save
      end

      microsecond_file @builder.makedepend_file => [
          @builder.scoped_task( :load_local_config ),
          @builder.scoped_task( :missing_headers ),
          @builder.objects_path,
          *@builder.project_files
      ] do
        system('which makedepend >/dev/null')
        raise 'makedepend not found' unless $?.success?
        @builder.logger.add( Logger::DEBUG, "Analysing dependencies" )
        command = "makedepend -f- -- #{ @builder.include_path } -- #{ file_list( @builder.source_files ) } 2>/dev/null > #{ @builder.makedepend_file }"
        system command
        #shell command
      end

      once_task @builder.scoped_task( :load_local_config ) => @builder.scoped_task( @builder.local_config ) do
        config = Rake::LocalConfig.new( @builder.local_config )
        config.load
        # TODO: put these back in builder
        @builder.include_paths       += Rake::Path.expand_all_with_root( config.include_paths, @rakefile_path )
        @builder.compilation_options += config.compilation_options
      end

      once_task @builder.scoped_task( :missing_headers ) => [ *@builder.generated_headers ] do
        @builder.missing_headers
      end

      # Reimplemented mkdepend file loading to make objects depend on
      # sources with the correct paths:
      # the standard rake mkdepend loader doesn't do what we want,
      # as it assumes files will be compiled in their own directory.
      task :load_makedepend => @builder.makedepend_file do
        object_to_source = @builder.source_files.inject( {} ) do | memo, source |
          mapped_object = source.gsub( '.' + @builder.source_file_extension, '.o' )
          memo[ mapped_object ] = source
          memo
        end
        File.open( @builder.makedepend_file ).each_line do |line|
          next if line !~ /:\s/
          mapped_object_file = $`
          header_files = $'.chomp
          # TODO: Why does it work,
          # if I make the object (not the source) depend on the header?
          source_file = object_to_source[ mapped_object_file ]
          object_file = object_path( source_file )
          object_file_task = Rake.application[ object_file ]
          object_file_task.enhance(header_files.split(' '))
        end
      end

      desc "List generated files (which are removed with 'rake #{ @builder.scoped_task( :clean ) }')"
      task :generated_files do
        puts @builder.generated_files.to_json
      end

      # Re-implement :clean locally for project and within namespace
      # Standard :clean is a singleton
      desc "Remove temporary files"
      task :clean do
        @builder.generated_files.each do |file|
          system "rm -f #{ file }"
          #shell "rm -f #{ file }"
        end
      end

      desc "Install '#{@builder.target_basename}' in '#{@builder.install_path}'"
      task :install, [] => [@builder.scoped_task(:build)] do
        destination = File.join(@builder.install_path, @builder.target_basename)
        @builder.install(@builder.target, destination)
        @builder.install_headers if @builder.target_type == :static_library
      end

      desc "Uninstall '#{ @builder.target_basename }' from '#{ @builder.install_path }'"
      task :uninstall, [] => [] do
        destination = File.join( @builder.install_path, @builder.target_basename )
        if ! File.exist?( destination )
          @builder.logger.add( Logger::INFO, "The file '#{ destination }' does not exist" )
          next
        end
        begin
          system "rm '#{destination}'"
          #shell "rm '#{destination}'", Logger::INFO
        rescue Errno::EACCES => e
          raise Error.new("You do not have permission to uninstall '#{destination}'\nTry\n $ sudo rake #{@builder.scoped_task(:uninstall)}", @builder.task_namespace)
        end
      end

      desc "Create a '#{@builder.makefile_name}' to build the project"
      file "#{@builder.makefile_name}" => [@builder.makedepend_file, @builder.scoped_task(:load_makedepend)] do
        Rake::Builder::Presenters::Makefile::BuilderPresenter.new(@builder).save
      end
    end

    def object_files
      @builder.source_files.map { |file| object_path(file) }
    end

    def build_commands
      case @builder.target_type
      when :executable
        [ "#{ @builder.linker } -o #{ @builder.target } #{ file_list( object_files ) } #{ @builder.link_flags }" ]
      when :static_library
        [ "#{ @builder.ar } -cq #{ @builder.target } #{ file_list( object_files ) }",
          "#{ @builder.ranlib } #{ @builder.target }" ]
      when :shared_library
        [ "#{ @builder.linker } -shared -o #{ @builder.target } #{ file_list( object_files ) } #{ @builder.link_flags }" ]
      else
        # TODO: raise an error
      end
    end

    def file_list( files, delimiter = ' ' )
      files.join( delimiter )
    end

    def define_compile_task(source)
      object = object_path(source)
      # TODO: put this back in builder
      @builder.generated_files << object
      file object => [ source ] do |t|
        @builder.logger.add( Logger::DEBUG, "Compiling '#{ source }'" )
        command = "#{ @builder.compiler } -c #{@builder.compiler_flags} -o #{ object } #{ source }"
        system(command)
        raise BuildFailure.new("Error: command '#{command}' failed") if not $?.success?
        #stdout, stderr = shell(command)
        #raise BuildFailure.new("Error: command '#{command}' failed: #{stderr} #{stdout}") if not $?.success?
      end
    end

    def object_path(source_path_name)
      o_name = File.basename(source_path_name).gsub('.' + @builder.source_file_extension, '.o')
      Rake::Path.expand_with_root(o_name, @builder.objects_path)
    end
  end
end

