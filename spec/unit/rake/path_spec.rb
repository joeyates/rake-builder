require 'spec_helper'

describe Rake::Path do
  let(:existing_file_path) { '/path/to/a/file' }
  let(:file_glob) { '/path/glob/*' }
  let(:file_list) { ['FILE', 'LIST'] }
  let(:a_path) { '/a/path' }

  context '.find_files' do
    it 'returns files passed in' do
      File.should_receive(:file?).with(existing_file_path).and_return(true)

      expect(Rake::Path.find_files([existing_file_path], 'c')).to eq([existing_file_path])
    end

    it 'returns a file list for globs' do
      FileList.should_receive(:[]).with(file_glob).and_return(file_list)

      expect(Rake::Path.find_files([file_glob], 'c')).to eq(file_list)
    end

    it 'searches for files with the given extension under a path' do
      FileList.should_receive(:[]).with(a_path + '/*.c').and_return(file_list)

      expect(Rake::Path.find_files([a_path], 'c')).to eq(file_list)
    end
  end
end

