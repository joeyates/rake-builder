require 'spec_helper'

describe 'the logger' do
  include RakeBuilderHelper

  let(:builder) { cpp_builder(:executable) }

  it 'can be read' do
    builder.logger.should_not be_nil
  end

  it 'can be set' do
    lambda do
      builder.logger = Logger.new(STDOUT)
    end.should_not raise_exception
  end
end

