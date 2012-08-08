require 'rake/tasklib'

module Rake
  class Builder < TaskLib

    module VERSION #:nodoc:
      MAJOR = 0
      MINOR = 0
      TINY  = 15

      STRING = [ MAJOR, MINOR, TINY ].join('.')
    end

  end

end

