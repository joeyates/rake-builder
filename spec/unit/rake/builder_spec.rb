require 'spec_helper'

describe Rake::Builder do
  include RakeBuilderHelper

  context '.create_autoconf' do
    let(:version) { stub('Rake::Builder::Autoconf::Autoconf::Version', :decide => 'qux') }
    let(:presenter) { stub('Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter', :save => nil) }
    let(:configure_ac) { stub('Rake::Builder::ConfigureAc', :save => nil) }

    before do
      Rake::Builder::Autoconf::Version.stub(:new).and_return(version)
      File.stub(:exist?).with('configure.ac').and_return(false)
      File.stub(:exist?).with('Makefile.am').and_return(false)
      Rake::Builder::ConfigureAc.stub(:new => configure_ac)
      Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter.stub(:new).and_return(presenter)
    end

    it 'fails if project_title is nil' do
      expect {
        Rake::Builder.create_autoconf(nil, 'bar', 'baz')
      }.to raise_error(RuntimeError, 'Please supply a project_title parameter')
    end

    it 'fails if Version fails' do
      Rake::Builder::Autoconf::Version.stub(:new).and_raise('foo')

      expect {
        Rake::Builder.create_autoconf('foo', 'bar', 'baz')
      }.to raise_error(RuntimeError, 'foo')
    end

    it 'fails if configure.ac exists' do
      File.should_receive(:exist?).with('configure.ac').and_return(true)

      expect {
        Rake::Builder.create_autoconf('foo', 'bar', 'baz')
      }.to raise_error(RuntimeError, "The file 'configure.ac' already exists")
    end

    it 'fails if Makefile.am exists' do
      File.should_receive(:exist?).with('Makefile.am').and_return(true)

      expect {
        Rake::Builder.create_autoconf('foo', 'bar', 'baz')
      }.to raise_error(RuntimeError, "The file 'Makefile.am' already exists")
    end

    it 'creates configure.ac' do
      Rake::Builder::ConfigureAc.should_receive(:new).and_return(configure_ac)

      Rake::Builder.create_autoconf('foo', 'bar', 'baz')
    end

    it 'creates Makefile.am' do
      Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter.should_receive(:new).and_return(presenter)

      Rake::Builder.create_autoconf('foo', 'bar', 'baz')
    end
  end

  context '#primary_name' do
    it 'returns a relative path' do
      here = File.expand_path(File.dirname(__FILE__))
      target_pathname = File.join(here, 'my_prog')
      builder = cpp_builder(:executable) { |b| b.target = target_pathname }

      expect(builder.primary_name).to eq(File.join('unit', 'rake', 'my_prog'))
    end
  end

  context '#label' do
    it 'replaces dots with underscores' do
      builder = cpp_builder(:executable) { |b| b.target = 'my_prog.exe' }

      expect(builder.label).to eq('my_prog_exe')
    end
  end

  context '#source_paths' do
    it 'returns source files' do
      builder = cpp_builder(:executable)

      expect(builder.source_paths).to eq(['projects/cpp_project/main.cpp'])
    end
  end

  context '#source_files' do
    it 'finds files with the .cpp extension' do
      Rake::Path.should_receive(:find_files).with(anything, 'cpp').and_return(['a.cpp'])

      cpp_builder(:executable)
    end

    it 'should allow configuration of source extension' do
      Rake::Path.should_receive(:find_files).with(anything, 'cc').and_return(['a.cc'])

      builder = cpp_builder(:executable) do |b|
        b.source_file_extension = 'cc'
      end
    end
  end

  context '#library_dependencies_list' do
    subject { cpp_builder(:executable) { |b| b.library_dependencies = ['foo', 'bar'] } }

    it 'is a string' do
      expect(subject.library_dependencies_list).to be_a(String)
    end

    it 'lists libraries' do
      expect(subject.library_dependencies_list).to eq('-lfoo -lbar')
    end
  end
end

