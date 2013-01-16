class Rake::Builder
  class Formatter < Logger::Formatter
    def call(severity, time, progname, msg)
      msg2str(msg) << "\n"
    end
  end
end

