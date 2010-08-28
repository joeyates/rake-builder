require 'rake/builder'

module Rake

  class QtBuilder < Builder

    # TODO:
    #   generate Info.plist
    #   package task

    attr_accessor :frameworks
    attr_accessor :resource_files
    attr_accessor :qt_version
    attr_accessor :architecture

    def initialize( &block )
      super( &block )
    end

    private

    # Overrrides

    def initialize_attributes
      super
      @programming_language  = 'c++'
      @header_file_extension = 'h'
      @frameworks            = [ 'QtGui', 'QtCore' ]
      @framework_paths       = [ '/Library/Frameworks' ]
      @compilation_defines   = '-DQT_GUI_LIB -DQT_CORE_LIB -DQT_SHARED'
      @moc_defines           = '-D__APPLE__ -D__GNUC__'
      @resource_files        = []
    end

    def configure
      raise 'programming_language must be C++' if @programming_language.downcase != 'c++'
      raise 'qt_version must be set'           if ! @qt_version

      super

      @resource_files      = Rake::Path.expand_all_with_root( @resource_files, @rakefile_path )
      @compilation_options += [ '-pipe', '-g', '-gdwarf-2', '-Wall', '-W' ]
      @compilation_options.uniq!
      @architecture        ||= 'i386'
      @compilation_options += [ architecture_option ]

      @frameworks.each do | framework |
        @include_paths << "/Library/Frameworks/#{ framework }.framework/Versions/#{ qt_major }/Headers"
        @include_paths << "/usr/include/#{ framework }"
      end
    end

    def define
      super
      define_moc_tasks
      define_resource_tasks
    end

    def generated_files
      super + moc_files + qrc_files
    end

    def source_files
      ( super + moc_files + qrc_files ).uniq
    end

    def compiler_flags
      [ compilation_options.join( ' ' ), @compilation_defines, include_path, framework_path_list ].join( ' ' )
    end

    def link_flags
      [ '-headerpad_max_install_names', architecture_option, @linker_options, library_paths_list, library_dependencies_list, framework_path_list, framework_list ].join( " " )
    end

    # QT-specific

    def qt_major
      @qt_version.match( /^(\d+)/ )[ 1 ]
    end

    def architecture_option
      "-arch #{ @architecture }"
    end

    def framework_path_list
      @framework_paths.map { |p| "-F#{ p }" }.join( " " )
    end

    def framework_list
      @frameworks.map { |p| "-framework #{ p }" }.join( " " )
    end
    
    # MOC

    def define_moc_tasks
      project_headers.each do | header |
        header_file = header[ :source_file ]
        moc         = moc_pathname( header_file )

        file moc => [ header_file ] do |t|
          command = "moc #{ @compilation_defines } #{ framework_path_list } #{ @moc_defines } #{ header_file } -o #{ moc }"
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
