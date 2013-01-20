require 'spec_helper'

describe Rake::Builder do
  context '.create_autoconf' do
    let(:version) { stub('Rake::Builder::Autoconf::Version', :decide => 'qux') }
    let(:presenter) { stub('Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter', :save => nil) }
    let(:configure_ac) { stub('Rake::Builder::ConfigureAc', :save => nil) }

    before do
      Rake::Builder::Version.stub(:new).and_return(version)
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
      Rake::Builder::Version.stub(:new).and_raise('foo')

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
    it 'xx'
  end

  context '#label' do
    it 'xx'
  end

  context '#source_paths' do
    it 'returns source files'
    it 'uses relative paths'
  end

  context '#library_dependencies_list' do
    it 'is a string'
  end
end

