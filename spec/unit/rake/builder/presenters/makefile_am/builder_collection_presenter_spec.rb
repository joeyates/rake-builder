require 'spec_helper'

describe Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter do
  context '.new' do
    it 'takes one parameter' do
      expect {
        Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter.new
      }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')
    end
  end

  context '#to_s' do
    let(:program_builder) { stub('Rake::Builder', :label => 'the_program', :is_library? => false) }
    let(:library_builder) { stub('Rake::Builder', :label => 'the_library', :is_library? => true) }
    let(:builders) { [program_builder, library_builder] }

    subject { Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter.new(builders) }

    before do
      Rake::Builder::Presenters::MakefileAm::BuilderPresenter.
        stub(:new).
        with(program_builder).
        and_return("AAA\nBBB\n")
      Rake::Builder::Presenters::MakefileAm::BuilderPresenter.
        stub(:new).
        with(library_builder).
        and_return("XXX\nYYY\n")
    end

    it 'lists libraries' do
      expect(subject.to_s).to include("lib_LIBRARIES = the_library\n\n")
    end

    it 'lists programs' do
      expect(subject.to_s).to include("bin_PROGRAMS = the_program\n\n")
    end

    it 'includes builder text' do
      Rake::Builder::Presenters::MakefileAm::BuilderPresenter.
        should_receive(:new).
        with(program_builder).
        and_return("AAA\nBBB\n")
      Rake::Builder::Presenters::MakefileAm::BuilderPresenter.
        should_receive(:new).
        with(library_builder).
        and_return("XXX\nYYY\n")

      output = subject.to_s

      expect(output).to include("AAA\nBBB\n")
      expect(output).to include("XXX\nYYY\n")
    end
  end
end

