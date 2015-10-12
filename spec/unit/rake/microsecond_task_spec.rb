require 'spec_helper'

describe Rake::Microsecond::DirectoryTask do
  let(:path) { '/a/path' }

  subject { described_class.define_task(path) }

  before do
    allow(subject).to receive(:mkdir_p)
    Rake::Task.clear
  end

  context '#needed?' do
    let(:directory_task) { instance_double(Rake::Microsecond::DirectoryTask) }
    let(:file_task) { instance_double(Rake::FileTask, timestamp: file_timestamp) }
    let(:needed_task) { double(Rake::Task, needed?: true) }
    let(:unneeded_task) { double(Rake::Task, needed?: false) }
    let(:directory_mtime) { 33 }
    let(:file_timestamp) { directory_mtime + 1 }

    context 'when the directory exists' do
      let(:exists) { true }
      let(:stat) { double(mtime: directory_mtime) }

      before do
        allow(File).to receive(:directory?) { exists }
        allow(File).to receive(:stat) { stat }
        allow(Rake.application).to receive(:[]).with(:directory_task) { directory_task }
        allow(directory_task).to receive(:is_a?).with(described_class) { true }
        allow(Rake.application).to receive(:[]).with(:file_task) { file_task }
        allow(file_task).to receive(:is_a?).with(Rake::FileTask) { true }
        allow(file_task).to receive(:is_a?).with(described_class) { false }
        allow(Rake.application).to receive(:[]).with(:needed) { needed_task }
        allow(Rake.application).to receive(:[]).with(:unneeded) { unneeded_task }
      end

      context 'if a prerequisite FileTask is more recent' do

        it 'is needed' do
          subject.enhance([:file_task])

          expect(subject).to be_needed
        end
      end

      it 'true if a prerequisite non-FileTask is needed?' do
        subject.enhance([:needed])

        expect(subject).to be_needed
      end

      it 'false otherwise' do
        subject.enhance([:unneeded])

        expect(subject).to_not be_needed
      end
    end
  end

  context '#execute' do
    let(:now) { 12345 }

    it 'memorizes the directory creation time including fractional seconds' do
      allow(Time).to receive(:now) { now }

      subject.execute

      expect(subject.timestamp).to eq(now)
    end
  end
end

