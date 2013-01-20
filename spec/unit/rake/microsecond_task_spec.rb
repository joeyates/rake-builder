require 'spec_helper'

describe Rake::Microsecond::DirectoryTask do
  let(:path) { '/a/path' }
  let(:task) do
    task = Rake::Microsecond::DirectoryTask.define_task(path)
    task.stub(:mkdir_p => nil)
    task
  end

  before do
    Rake::Task.clear
  end

  context '#needed?' do
    let(:base_time) { Time.now }
    let(:task1) { Rake::Microsecond::DirectoryTask.define_task('/path1') }
    let(:task2) { Rake::Microsecond::DirectoryTask.define_task('/path2') }
    let(:needed_task) { Rake::Task.define_task('needed') }
    let(:unneeded_task) { Rake::Task.define_task('unneeded') }

    context 'when the directory exists' do
      before do
        File.stub(:directory? => true)
        File.stub_chain(:stat, :mtime).and_return(33)
      end

      it 'true if a prerequisite FileTask is more recent' do
        task1.timestamp = base_time - 10
        task2.timestamp = base_time - 1
        task1.enhance([task2])

        expect(task1).to be_needed
      end

      it 'true if a prerequisite non-FileTask is needed?' do
        task.enhance([needed_task])

        expect(task).to be_needed
      end

      it 'false otherwise' do
        task.enhance([unneeded_task])
        unneeded_task.stub(:needed? => false)

        expect(task).to_not be_needed
      end
    end
  end

  context '#execute' do
    let(:stub_time) { stub('Time') }

    it 'memorizes the directory creation time including fractional seconds' do
      Time.stub(:now => stub_time)

      task.execute

      expect(task.timestamp).to eq(stub_time)
    end
  end
end

