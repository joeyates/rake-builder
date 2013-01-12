require 'spec_helper'

describe Rake::Builder do
  include RakeBuilderHelper

  def builder(type)
    c_task(type)
  end

  [
    [:static_library, true],
    [:shared_library, true],
    [:executable,     false]
  ].each do |type, is_library|
    example type do
      expect(builder(type).is_library?).to eq(is_library)
    end
  end
end

