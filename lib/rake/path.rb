require 'rubygems' if RUBY_VERSION < '1.9'

module Rake

  module Path

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

  end

end
