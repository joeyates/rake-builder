class Rake::Builder
    class Configuration
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
        self.installable_headers = paths
      end

      # (Optional) namespace for tasks
      attr_accessor :task_namespace

      # Name of the default task
      attr_accessor :default_task

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

      # Tasks which the target file depends upon
      attr_accessor :target_prerequisites

      def initialize(block)
        raise 'No block given' if block.nil?
        set_defaults
        save_rakefile_info(block)
        block.call(self)
        configure
      end

      private

      def set_defaults
        self.architecture          = 'i386'
        self.programming_language  = 'c++'
        self.header_file_extension = 'h'
        self.objects_path          = '.'
        self.library_paths         = []
        self.library_dependencies  = []
        self.source_search_paths   = ['.']
        self.target                = './a.out'
        self.compilation_options   = []
        self.include_paths         = ['./include']
        self.installable_headers   ||= []
        self.target_prerequisites  = []
      end

      def save_rakefile_info(block)
        if RUBY_VERSION < '1.9'
          # Hack the path from the block String representation
          @rakefile = block.to_s.match(/@([^\:]+):/)[1]
        else
          @rakefile = block.source_location[0]
        end
        @rakefile      = File.expand_path(rakefile)
        @rakefile_path = File.dirname(rakefile)
      end

      def configure
        self.compilation_options += [architecture_option] if RUBY_PLATFORM =~ /apple/i
        self.compilation_options.uniq!

        self.programming_language = programming_language.to_s.downcase
        raise Error.new("Don't know how to build '#{programming_language}' programs", task_namespace) if KNOWN_LANGUAGES[programming_language].nil?
        self.compiler              ||= KNOWN_LANGUAGES[programming_language][:compiler]
        self.linker                ||= KNOWN_LANGUAGES[programming_language][:linker]
        self.ar                    ||= KNOWN_LANGUAGES[programming_language][:ar]
        self.ranlib                ||= KNOWN_LANGUAGES[programming_language][:ranlib]
        self.source_file_extension ||= KNOWN_LANGUAGES[programming_language][:source_file_extension]

        raise Error.new("The target name cannot be nil", task_namespace)             if target.nil?
        raise Error.new("The target name cannot be an empty string", task_namespace) if target == ''

        self.target_type           ||= to_target_type(target)
        raise Error.new("Building #{target_type} targets is not supported", task_namespace) if ! TARGET_TYPES.include?(target_type)

        self.install_path          ||= default_install_path(target_type)

        self.linker_options        ||= ''

        self.default_task          ||= :build
        self.target_prerequisites  << rakefile
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

      def default_install_path(target_type)
        case target_type
        when :executable
          '/usr/local/bin'
        else
          '/usr/local/lib'
        end
      end
    end
end

