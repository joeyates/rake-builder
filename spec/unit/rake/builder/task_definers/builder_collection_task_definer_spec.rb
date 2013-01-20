require 'spec_helper'

describe Rake::Builder::BuilderCollectionTaskDefiner do
  context '#run' do
    subject { Rake::Builder::BuilderCollectionTaskDefiner.new }

    before do
      Rake::Task.clear
    end

    it 'defines an autoconf task' do
      subject.run

      expect(Rake::Task.task_defined?('autoconf')).to be_true
    end

    it 'calls create_autoconf' do
      Rake::Builder.instances << stub(
        'Rake::Builder',
        :source_files => ['foo'],
        :rakefile_path => '/path',
      )

      subject.run

      Rake::Builder.should_receive(:create_autoconf)

      Rake::Task['autoconf'].invoke
    end

    it 'fails if no builders have been instantiated' do
      Rake::Builder.instances.clear

      subject.run

      expect {
        Rake::Task['autoconf'].invoke
      }.to raise_error(RuntimeError, 'No Rake::Builder projects have been defined')
    end
  end
end

