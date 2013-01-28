module Rake
  module Path
    def self.find_files(paths, extension)
      files = paths.reduce([]) do |memo, path|
        case
        when File.file?(path)
          files = FileList[path]
        when path.match(/[\*\?]/)
          files = FileList[path]
        else
          files = FileList[path + '/*.' + extension]
        end
        memo + files
      end
    end
  end
end

