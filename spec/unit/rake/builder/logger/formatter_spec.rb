require 'spec_helper'

describe 'Rake::Builder::Logger::Formatter' do
  let(:formatter) { Rake::Builder::Logger::Formatter.new }
  let(:stream) { StringIO.new }
  let(:logger) do
    logger = Logger.new(stream)
    logger.formatter = formatter
    logger
  end

  context '#call' do
    it 'only prints the supplied string' do
      logger.info 'foo'

      expect(stream.string).to eq("foo\n")
    end
  end
end

