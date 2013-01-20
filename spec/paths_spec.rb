require 'spec_helper'

describe 'when creating tasks' do
  let(:builder) { cpp_builder('foo') }

  it 'remembers the Rakefile path' do
    here = File.dirname(File.expand_path(__FILE__))
    builder = Rake::Builder.new { |b| b.source_search_paths = ['projects/cpp_project'] }

    expect(builder.rakefile_path).to eq(here)
  end
end

