require 'spec_helper'

describe Rake::Builder do
  context '.create_makefile_am' do
    let(:presenter) { stub('Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter', :to_s => 'contents') }

    before do
      Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter.stub(:new).and_return(presenter)
      File.stub(:open).with('Makefile.am', 'w')
    end

    it 'uses the presenter' do
      Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter.should_receive(:new).and_return(presenter)

      Rake::Builder.create_makefile_am
    end

    it 'writes Makefile.am' do
      file = stub('File')
      file.should_receive(:write).with('contents')
      File.should_receive(:open).with('Makefile.am', 'w') do |&block|
        block.call file
      end

      Rake::Builder.create_makefile_am
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

