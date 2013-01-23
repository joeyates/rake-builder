require 'spec_helper'

describe Rake::Builder::Installer do
  let(:destination_path) { '/destination/path' }
  let(:destination_pathname) { '/destination/path/install' }

  context '#install' do
    let(:file_to_install) { '/file/to/install' }

    before do
      File.stub(:exist?).with(file_to_install).and_return(true)
      File.stub(:exist?).with(destination_path).and_return(true)
      File.stub(:directory?).with(destination_path).and_return(true)
      File.stub(:writable?).with(destination_path).and_return(true)
      File.stub(:file?).with(destination_pathname).and_return(false)
      File.stub(:writable?).with(destination_pathname).and_return(true)
      FileUtils.stub(:copy_file).with(file_to_install, destination_path)
    end

    it 'checks the source exists' do
      File.should_receive(:exist?).with(file_to_install).and_return(true)

      subject.install file_to_install, destination_path
    end

    it 'fails if the source does not exist' do
      File.stub(:exist?).with(file_to_install).and_return(false)

      expect {
        subject.install file_to_install, destination_path
      }.to raise_error(RuntimeError, /does not exist/)
    end

    it 'checks the destination directory exists' do
      File.should_receive(:exist?).with(destination_path).and_return(false)

      expect {
        subject.install file_to_install, destination_path
      }.to raise_error(RuntimeError, /does not exist/)
    end

    it 'checks the destination is a directory' do
      File.should_receive(:directory?).with(destination_path).and_return(false)

      expect {
        subject.install file_to_install, destination_path
      }.to raise_error(RuntimeError, /is not a directory/)
    end

    it 'check it can overwrite an existing destination file' do
      File.stub(:file?).with(destination_pathname).and_return(true)
      File.stub(:writable?).with(destination_pathname).and_return(false)

      expect {
        subject.install file_to_install, destination_path
      }.to raise_error(RuntimeError, /cannot be overwritten/)
    end

    it 'copies the file to the destination' do
      FileUtils.should_receive(:copy_file).with(file_to_install, destination_path)

      subject.install file_to_install, destination_path
    end
  end

  context '#uninstall' do
    before do
      File.stub(:exist?).with(destination_pathname).and_return(true)
      File.stub(:writable?).with(destination_path).and_return(true)
      File.stub(:unlink).with(destination_pathname)
    end

    it 'checks if the file exists' do
      File.should_receive(:exist?).with(destination_pathname).and_return(true)

      subject.uninstall destination_pathname
    end

    it 'does nothing if the file does not exist' do
      File.should_receive(:exist?).with(destination_pathname).and_return(false)
      File.should_not_receive(:unlink)

      subject.uninstall destination_pathname
    end

    it 'fails if the directory is not writable' do
      File.should_receive(:writable?).with(destination_path).and_return(false)

      expect {
        subject.uninstall destination_pathname
      }.to raise_error(RuntimeError, /directory.*?writable/)
    end

    it 'deletes the file' do
      File.should_receive(:unlink).with(destination_pathname)

      subject.uninstall destination_pathname
    end
  end
end

