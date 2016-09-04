require 'spec_helper'

describe Rake::Builder::Presenters::MakefileAm::BuilderPresenter do
  context '.new' do
    it 'takes one parameter' do
      expect {
        described_class.new
      }.to raise_error(ArgumentError, /wrong number of arguments/)
    end
  end

  context '#to_s' do
    let(:builder) do
      double(
        Rake::Builder,
        is_library?:               is_library?,
        label:                     'fubar',
        source_files:              ['path/to/1', 'path/to/2'],
        compiler_flags:            '-D FOO -D BAR',
        library_dependencies_list: library_dependencies_list
      )
    end
    let(:library_dependencies_list) { [] }
    let(:is_library?) { true }

    subject { described_class.new(builder) }

    it 'lists sources' do
      sources_match = %r(fubar_SOURCES\s+=\s+path/to/1 path/to/2)
      expect(subject.to_s).to match(sources_match)
    end

    it 'shows cpp flags' do
      expect(subject.to_s).to match(/fubar_CPPFLAGS\s+=\s+-D FOO -D BAR/)
    end

    it 'ends with a blank line' do
      expect(subject.to_s).to end_with("\n")
    end

    context 'library builder' do
      it "doesn't show ld flags" do
        expect(subject.to_s).to_not include('fubar_LDFLAGS')
      end

      it "doesn't list library dependencies" do
        expect(subject.to_s).to_not include('fubar_LDADD')
      end
    end

    context 'executable builder' do
      let(:is_library?) { false }
      let(:library_dependencies_list) { '-lfoo -lbar' }

      it 'shows ld flags' do
        expect(subject.to_s).to match(%r(fubar_LDFLAGS\s+=\s+-L))
      end

      it "lists library dependencies" do
        expect(subject.to_s).to match(%r(fubar_LDADD\s+=\s+-lfoo -lbar))
      end
    end
  end
end
