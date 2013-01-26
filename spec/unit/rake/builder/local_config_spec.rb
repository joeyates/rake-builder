require 'spec_helper'

describe Rake::Builder::LocalConfig do
  let(:local_config_file) { 'local_config' }
  let(:include_paths) { ['/foo/bar'] }
  let(:compilation_options) { ['foo', 'bar'] }
  let(:config_data) do
    {
      :rake_builder => {
        :config_file => {:version => '1.1'},
      },
      :include_paths => include_paths,
      :compilation_options => compilation_options,
    }
  end
  let(:bad_config_data) do
    config_data[:rake_builder][:config_file][:version] = '0.1'
    config_data
  end

  before { YAML.stub(:load_file).and_return(config_data) }

  subject { Rake::Builder::LocalConfig.new(local_config_file) }

  context '#load' do
    it 'loads the file' do
      YAML.should_receive(:load_file).and_return(config_data)

      subject.load
    end

    it 'fails if the version is not recognized' do
      YAML.should_receive(:load_file).and_return(bad_config_data)

      expect {
        subject.load
      }.to raise_error(Rake::Builder::Error, /version incorrect/)
    end

    it 'sets the include_paths' do
      subject.load

      expect(subject.include_paths).to eq(include_paths)
    end

    it 'sets compilation_options' do
      subject.load

      expect(subject.compilation_options).to eq(compilation_options)
    end
  end
end

