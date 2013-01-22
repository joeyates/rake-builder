require 'spec_helper'

describe Rake::Builder::ConfigureAc do
  subject { Rake::Builder::ConfigureAc.new('title', '1.2.3', '/source/file.c') }

  context '.new' do
    it 'takes three parameters' do
      expect {
        Rake::Builder::ConfigureAc.new
      }.to raise_error(ArgumentError, /wrong number of arguments/)
    end
  end

  context '#to_s' do
    it 'sets up AC_INIT' do
      expected = 'AC_INIT(title, 1.2.3)'

      expect(subject.to_s).to include(expected)
    end

    it 'indicates a source file in AC_CONFIG_SRCDIR' do
      expected = 'AC_CONFIG_SRCDIR([/source/file.c])'

      expect(subject.to_s).to include(expected)
    end

    it 'sets up AM_INIT_AUTOMAKE' do
      expected = 'AM_INIT_AUTOMAKE([title], [1.2.3])'

      expect(subject.to_s).to include(expected)
    end
  end

  context '#save' do
    it 'creates the file' do
      File.should_receive(:open).with('configure.ac', 'w')

      subject.save
    end

    it 'saves the content' do
      file = stub('File')
      File.stub(:open).with('configure.ac', 'w') do |&block|
        block.call file
      end

      file.should_receive(:write).with(/AC_PREREQ\(2\.61\)/)

      subject.save
    end
  end
end

