require 'rake/builder'

module Rake

  class QtBuilder < Builder

    # TODO:
    #   generate Info.plist
    #   package task

    attr_accessor :qt_version
    attr_accessor :frameworks
    attr_accessor :resource_files
    attr_accessor :ui_files

    def initialize( &block )
      super( &block )
    end

    private

    # Overrrides

    def initialize_attributes
      super
      @programming_language  = 'c++'
      @header_file_extension = 'h'
      @frameworks            = []
      case
      when RUBY_PLATFORM =~ /linux$/
        @include_paths         << '/usr/include/qt4'
        @moc_defines           = [ '-D__GNUC__' ]
      when RUBY_PLATFORM =~ /darwin/i
        @framework_paths       = [ '/Library/Frameworks' ]
        @moc_defines           = [ '-D__APPLE__',  '-D__GNUC__' ]
      else
        raise BuilderError.new( "Unrecognised platform" )
      end
      @compilation_defines   = [ '-DQT_GUI_LIB', '-DQT_CORE_LIB', '-DQT_SHARED' ]
      @resource_files        = []
      @ui_files              = []
    end

    def configure
      raise BuilderError.new( 'programming_language must be C++' ) if @programming_language.downcase != 'c++'
      raise BuilderError.new( 'qt_version must be set' )           if ! @qt_version

      super

      @resource_files      = Rake::Path.expand_all_with_root( @resource_files, @rakefile_path )
      @ui_files            = Rake::Path.expand_all_with_root( @ui_files, @rakefile_path )
      @compilation_options += [ '-pipe', '-g', '-gdwarf-2', '-Wall', '-W' ]
      @include_paths << @objects_path # for UI headers
    end

    def define
      super
      define_ui_tasks
      define_moc_tasks
      define_resource_tasks
    end

    def generated_files
      super + moc_files + ui_headers + qrc_files
    end

    def generated_headers
      super + ui_headers
    end

    def source_files
      ( super + moc_files + qrc_files ).uniq
    end

    def header_files
      ( super + ui_headers ).uniq
    end

    def compiler_flags
      flags = compilation_options + @compilation_defines + [ include_path ]
      if RUBY_PLATFORM =~ /darwin/i
        flags += framework_paths
        flags << architecture_option
      end
      flags.join( ' ' )
    end

    def link_flags
      flags = [ @linker_options, library_paths_list, library_dependencies_list ]
      if RUBY_PLATFORM =~ /darwin/i
        flags += [ '-headerpad_max_install_names', architecture_option ]
        flags += framework_paths + framework_options
      end
      flags.join( ' ' )
    end

    # Exclude paths like QtFoo/Bar, but grab frameworks
    def missing_headers
      super
      @missing_headers.reject! do | path |
        m = path.match( /^(Qt\w+)\/(\w+?(?:\.h)?)$/ )
        if m
          framework      = m[ 1 ]
          @frameworks << framework
          framework_path = Compiler::GCC.framework_path( framework, qt_major )
          header_path    = "#{ framework_path }/#{ m[ 2 ] }"
          File.exist?( header_path )
        else
          false
        end
      end

      @frameworks.each do | framework |
        @include_paths << Compiler::GCC.framework_path( framework, qt_major )
        @include_paths << "/usr/include/#{ framework }"
      end

      # Last chance: exclude headers of the form 'Aaaaaa' if found under frameworks
      @missing_headers.reject! do | header |
        @frameworks.any? do | framework |
          framework_path = Compiler::GCC.framework_path( framework, qt_major )
          header_path    = "#{ framework_path }/#{ header }"
          File.exist?( header_path )
        end
      end

      @missing_headers
    end

    # QT-specific

    def qt_major
      @qt_version.match( /^(\d+)/ )[ 1 ]
    end

    def framework_paths
      @framework_paths.map { |p| "-F#{ p }" }
    end

    def framework_options
      @frameworks.map { |p| "-framework #{ p }" }
    end

    # UI
    # /Developer/Tools/Qt/uic ../scanner_cpp/mainwindow.ui -o ui_mainwindow.h

    def define_ui_tasks
      @ui_files.each do | ui_file |
        ui_header = ui_header_path( ui_file )
        file ui_header => [ @objects_path, ui_file ] do |t|
          command = "uic #{ ui_file } -o #{ ui_header }"
          shell command
        end
      end
    end

    def ui_headers
      @ui_files.collect do | ui_file |
        ui_header_path( ui_file )
      end
    end

    def ui_header_path( ui_file )
      header_name = 'ui_' + File.basename( ui_file ).gsub( '.ui', '.h' )
      Rake::Path.expand_with_root( header_name, @objects_path )
    end

    # MOC

    def define_moc_tasks
      project_headers.each do | header |
        header_file = header[ :source_file ]
        moc         = moc_pathname( header_file )

        file moc => [ header_file ] do |t|
          options = @compilation_defines
          options += framework_paths if RUBY_PLATFORM =~ /darwin/i
          options += @moc_defines
          command = "moc #{ options.join( ' ' ) } #{ header_file } -o #{ moc }"
          shell command
        end

        define_compile_task( moc )
      end
    end

    def moc_files
      @moc_files ||= project_headers.collect do | header |
        moc_pathname( header[ :source_file ] )
      end
    end

    def moc_pathname( header_name )
      moc_name = 'moc_' + File.basename( header_name ).gsub( '.' + @header_file_extension, '.cpp' )
      Rake::Path.expand_with_root( moc_name, @objects_path )
    end

    # Resources

    def define_resource_tasks
      @resource_files.each do | resource |
        qrc = qrc_pathname( resource )
        file qrc => [ resource ] do |t|
          command = "rcc -name #{ target_basename } #{ resource } -o #{ qrc }"
          shell command
        end
      end
    end

    def qrc_files
      @resource_files.collect do | resource |
        qrc_pathname( resource )
      end
    end

    def qrc_pathname( resource_name )
      qrc_name = 'qrc_' + File.basename( resource_name ).gsub( '.qrc', '.cpp' )
      Rake::Path.expand_with_root( qrc_name, @objects_path )
    end

  end

end
