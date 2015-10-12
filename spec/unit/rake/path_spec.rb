require 'spec_helper'

describe Rake::Path do
  let(:existing_file_path) { '/path/to/a/file' }
  let(:file_glob) { '/path/glob/*' }
  let(:file_list) { ['FILE', 'LIST'] }
  let(:a_path) { '/a/path' }

  context '.find_files' do
    context 'with files passed in' do
      context 'if they exist' do
        before do
          allow(File).to receive(:file?).with(existing_file_path) { true }
        end

        it 'returns the files' do
          expect(described_class.find_files([existing_file_path], 'c')).to eq([existing_file_path])
        end
      end
    end

    context 'with globs' do
      before do
        allow(FileList).to receive(:[]).with(file_glob) { file_list }
      end

      it 'returns a file list' do
        expect(described_class.find_files([file_glob], 'c')).to eq(file_list)
      end
    end

    context 'when given a path' do
      before do
        allow(FileList).to receive(:[]).with(a_path + '/*.c') { file_list }
      end

      it 'returns a file list' do
        expect(described_class.find_files([a_path], 'c')).to eq(file_list)
      end
    end
  end
end
