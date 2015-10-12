require 'spec_helper'

describe Rake::Builder::Installer do
  let(:destination_path) { '/destination/path' }
  let(:destination_pathname) { File.join(destination_path, 'install') }
  let(:destination_path_writable) { true }

  before do
    allow(File).to receive(:writable?).with(destination_path) { destination_path_writable }
  end

  context '#install' do
    let(:file_to_install) { '/file/to/install' }
    let(:file_to_install_exists) { true }
    let(:destination_path_exists) { true }
    let(:destination_path_directory) { true }
    let(:destination_pathname_file) { true }
    let(:destination_pathname_writable) { true }

    before do
      allow(File).to receive(:exist?).with(file_to_install) { file_to_install_exists }
      allow(File).to receive(:exist?).with(destination_path) { destination_path_exists }
      allow(File).to receive(:directory?).with(destination_path) { destination_path_directory }
      allow(File).to receive(:file?).with(destination_pathname) { destination_pathname_file }
      allow(File).to receive(:writable?).with(destination_pathname) { destination_pathname_writable }
      allow(FileUtils).to receive(:copy_file).with(file_to_install, destination_path)
    end

    context 'if the source does not exist' do
      let(:file_to_install_exists) { false }

      it 'fails' do
        expect {
          subject.install file_to_install, destination_path
        }.to raise_error(RuntimeError, /does not exist/)
      end
    end

    context 'if the destination directory does not exist' do
      let(:destination_path_exists) { false }

      it 'fails' do
        expect {
          subject.install file_to_install, destination_path
        }.to raise_error(RuntimeError, /does not exist/)
      end
    end

    context 'if the destination is not a directory' do
      let(:destination_path_directory) { false }

      it 'fails' do
        expect {
          subject.install file_to_install, destination_path
        }.to raise_error(RuntimeError, /is not a directory/)
      end
    end

    context 'if it cannot overwrite an existing destination file' do
      let(:destination_pathname_file) { true }
      let(:destination_pathname_writable) { false }

      it 'fails' do
        expect {
          subject.install file_to_install, destination_path
        }.to raise_error(RuntimeError, /cannot be overwritten/)
      end
    end

    it 'copies the file to the destination' do
      subject.install file_to_install, destination_path

      expect(FileUtils).to have_received(:copy_file).with(file_to_install, destination_path)
    end
  end

  context '#uninstall' do
    let(:destination_pathname_exist) { true }

    before do
      allow(File).to receive(:exist?).with(destination_pathname) { destination_pathname_exist }
      allow(File).to receive(:unlink).with(destination_pathname)
    end

    context 'if the file does not exist' do
      let(:destination_pathname_exist) { false }

      it 'does nothing' do
        subject.uninstall destination_pathname

        expect(File).to_not have_received(:unlink)
      end
    end

    context 'if the directory is not writable' do
      let(:destination_path_writable) { false }

      it 'fails' do
        expect {
          subject.uninstall destination_pathname
        }.to raise_error(RuntimeError, /directory.*?writable/)
      end
    end

    it 'deletes the file' do
      subject.uninstall destination_pathname

      expect(File).to have_received(:unlink).with(destination_pathname)
    end
  end
end

