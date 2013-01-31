require 'spec_helper'

describe Rake::Builder::Configuration do
  subject { Rake::Builder::Configuration.new(Proc.new {}) }

  context '#load_local_config' do
    let(:config_include_paths) { ['/path/one', '/path/two'] }
    let(:config_compilation_options) { ['opt1', 'opt2'] }
    let(:local_config) do
      stub(
        'Rake::Builder::LocalConfig',
        :load => nil,
        :include_paths => config_include_paths,
        :compilation_options => config_compilation_options,
      )
    end

    before { Rake::Builder::LocalConfig.stub(:new => local_config) }

    it 'loads local config' do
      Rake::Builder::LocalConfig.should_receive(:new).
        with(/\.rake-builder/).and_return(local_config)
      local_config.should_receive(:load).with()

      subject.load_local_config
    end

    it 'adds include paths' do
      original = subject.include_paths.clone

      subject.load_local_config

      expect(subject.include_paths).to eq(original + config_include_paths)
    end

    it 'adds compilation options' do
      original = subject.compilation_options.clone

      subject.load_local_config

      expect(subject.compilation_options).to eq(original + config_compilation_options)
    end
  end

  context '#create_local_config' do
    let(:local_config) do
      stub(
        'Rake::Builder::LocalConfig',
        :include_paths=        => nil,
        :save                  => nil
      )
    end

    before { Rake::Builder::LocalConfig.stub(:new).and_return(local_config) }

    it 'saves a LocalConfig' do
      local_config.should_receive(:save)

      subject.create_local_config([])
    end
  end
end

