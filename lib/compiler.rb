
module Compiler

  class Base
    EXTRA_PATHS = [ '/opt/local/include' ]

    def self.for( compiler )
      COMPILERS[ compiler ].new
    end

    def initialize
      @paths = {}
    end

    def include_paths( headers )
      paths = []
      headers.each do | header |
        path = find_header( header )
        raise "Can't find header '#{ header }' in any known include path" if path.nil?
        paths << path
      end
      paths.uniq
    end

    private

    def find_header( header )
      EXTRA_PATHS.each do | path |
        if File.exist?( "#{ path }/#{ header }" )
          return path
        end
      end
      nil
    end

  end

  class GCC < Base

    def self.framework_path( framework, qt_major )
      "/Library/Frameworks/#{ framework }.framework/Versions/#{ qt_major }/Headers"
    end

    def default_include_paths( language )
      return @paths[ language ] if @paths[ language ]

      paths = []
      # Below is the recommended(!) way of getting standard serach paths from GCC
      output = `echo | gcc -v -x #{ language } -E - 2>&1 1>/dev/null`
      collecting = false
      output.each_line do | line |
        case
        when line =~ /#include <\.\.\.> search starts here:/
          collecting = true
        when line =~ /End of search list\./
          collecting = false
        when line =~ / \(framework directory\)/
          # Skip frameworks
        else
          paths << line.strip if collecting
        end
      end

      @paths[ language ] = paths
    end

    def missing_headers( include_paths, source_files )
      include_path = include_paths.map { | path | "-I#{ path }" }.join( ' ' )
      command      = "makedepend -f- -- #{ include_path } -- #{ source_files.join( ' ' ) } 2>&1 1>/dev/null"
      output       = `#{ command }`
      missing      = []
      output.each do | line |
        match = line.match( /cannot find include file "([^"]*)"/m )
        missing << match[ 1 ] if match
      end

      missing
    end

  end

  COMPILERS = { :gcc => GCC }

end
