require 'spec_helper'

describe Rake::Builder::LocalConfig do
  let(:local_config_file) { 'local_config' }
  let(:include_paths) { [] }
  let(:compilation_options) { [] }
  let(:good_config_data) do
    {
      :rake_builder => {
        :config_file => {:version => '1.1'},
      },
      :include_paths => include_paths,
      :compilation_options => compilation_options,
    }
  end
  let(:bad_config_data) do
    config = good_config_data.clone
    config[:rake_builder][:config_file][:version] = '0.1'
    config
  end
  let(:config_data) { good_config_data }

  before { allow(YAML).to receive(:load_file) { config_data } }

  subject { described_class.new(local_config_file) }

  context '#load' do
    let(:include_paths) { ['/foo/bar'] }
    let(:compilation_options) { ['foo', 'bar'] }

    context 'if the version is not recognized' do
      let(:config_data) { bad_config_data }

      it 'fails' do
        expect {
          subject.load
        }.to raise_error(Rake::Builder::Error, /version incorrect/)
      end
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

  context '#save' do
    let(:file) { double(File, write: nil) }
    let(:data) { config_data.to_yaml }

    before do
      allow(File).to receive(:open).with(local_config_file, 'w').and_yield(file)
    end

    it 'writes to the file' do
      subject.save

      expect(file).to have_received(:write).with(data)
    end
  end
end

