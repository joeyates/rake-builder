class Rake::Builder
  class Error < StandardError
    attr_accessor :namespace

    def initialize(message, namespace = nil)
      super(message)
      @namespace = namespace
    end

    def to_s
      message = super
      message = "#{@namespace}: #{message}" if @namespace
      message
    end
  end
end

