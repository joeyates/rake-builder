require 'spec_helper'

describe Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter do
  context '.new' do
    it 'takes one parameter' do
      expect {
        Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter.new
      }.to raise_error(ArgumentError, /wrong number of arguments/)
    end
  end

  context '#to_s' do
    let(:program_builder) { double(Rake::Builder, :label => 'the_program', :target_path => 'the_program', :is_library? => false) }
    let(:library_builder) { double(Rake::Builder, :label => 'the_library', :target_path => 'the_library', :is_library? => true) }
    let(:builders) { [program_builder, library_builder] }

    subject { described_class.new(builders) }

    before do
      allow(Rake::Builder::Presenters::MakefileAm::BuilderPresenter)
        .to receive(:new).with(program_builder) { "AAA\nBBB\n" }
      allow(Rake::Builder::Presenters::MakefileAm::BuilderPresenter)
        .to receive(:new). with(library_builder) { "XXX\nYYY\n" }
    end

    it 'lists libraries' do
      expect(subject.to_s).to include("lib_LIBRARIES = the_library\n\n")
    end

    it 'lists programs' do
      expect(subject.to_s).to include("bin_PROGRAMS = the_program\n\n")
    end

    it 'includes builder text' do
      output = subject.to_s

      expect(output).to include("AAA\nBBB\n")
      expect(output).to include("XXX\nYYY\n")
    end
  end
end
