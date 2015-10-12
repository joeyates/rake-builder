require 'spec_helper'

describe Rake::Builder::BuilderCollectionTaskDefiner do
  context '#run' do
    let(:builder) do
      double(
        Rake::Builder,
        source_files: ['foo'],
        rakefile_path: '/path',
        is_library?: false,
        target_path: '/path2',
        label: 'path2',
        compiler_flags: [],
        library_dependencies_list: [],
      )
    end
    let(:params) { ['foo', '1.11.1111'] }

    before do
      Rake::Task.clear
      allow(Rake::Builder).to receive(:create_autoconf)
    end

    it 'defines an autoconf task' do
      subject.run

      expect(Rake::Task.task_defined?('autoconf')).to be_truthy
    end

    it 'calls create_autoconf' do
      Rake::Builder.instances << builder

      subject.run

      Rake::Task['autoconf'].invoke(*params)

      expect(Rake::Builder).to have_received(:create_autoconf)
    end

    it 'fails if no builders have been instantiated' do
      Rake::Builder.instances.clear

      subject.run

      expect {
        Rake::Task['autoconf'].invoke(*params)
      }.to raise_error(RuntimeError, 'No Rake::Builder projects have been defined')
    end
  end
end

