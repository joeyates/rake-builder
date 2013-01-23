require 'logger'

class Rake::Builder
  module Logger; end
end

module Rake::Builder::Logger
  class Formatter < ::Logger::Formatter
    def call(severity, time, progname, msg)
      msg2str(msg) << "\n"
    end
  end
end

