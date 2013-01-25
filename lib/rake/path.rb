module Rake

  module Path

    def self.find_files( paths, extension )
      files = paths.reduce( [] ) do | memo, path |
        case
        when File.file?( path )
          files = FileList[ path ]
        when ( path =~ /[\*\?]/ )
          files = FileList[ path ]
        else
          files = FileList[ path + '/*.' + extension ]
        end
        memo + files
      end
    end

    # Expand path to an absolute path relative to the supplied root
    def self.expand_with_root( path, root )
      if path =~ /^\//
        File.expand_path( path )
      else
        File.expand_path( root + '/' + path )
      end
    end

    # Expand an array of paths to absolute paths relative to the supplied root
    def self.expand_all_with_root( paths, root )
      paths.map{ |path| expand_with_root( path, root ) }
    end

    def self.relative_path( path, prefix, options = {} )
      return path if prefix.nil?
      m = path.match( /^#{ prefix }\/?/ )
      if ! m.nil?
        if options[ :initial_dot_slash ]
          "./#{ m.post_match }"
        else
          m.post_match
        end
      else
        path
      end
    end

  end

end
