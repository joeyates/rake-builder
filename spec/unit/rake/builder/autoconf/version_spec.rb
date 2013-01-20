require 'spec_helper'

describe Rake::Builder::Autoconf::Version do
  context '.new' do
    context 'with parameter' do
      it 'fails if the version parameter is not nn.nn.nn' do
        expect {
          Rake::Builder::Autoconf::Version.new('hello')
        }.to raise_error(RuntimeError, /badly formatted/)
      end
    end

    context 'without parameter' do
      it 'succeeds' do
        Rake::Builder::Autoconf::Version.new
      end
    end

    context 'VERSION file' do
      before do
        File.stub(:exist? => true)
        File.stub(:read => '1.2.3')
      end

      it 'checks for a the file' do
        File.should_receive(:exist?).
          with('VERSION').
          and_return(false)

        Rake::Builder::Autoconf::Version.new
      end

      it 'loads the file' do
        File.should_receive(:exist?).
          with('VERSION').
          and_return(true)
        File.should_receive(:read).
          with('VERSION').
          and_return('1.2.3')

        Rake::Builder::Autoconf::Version.new
      end

      it 'fails if the version is badly formed' do
        File.should_receive(:read).
          with('VERSION').
          and_return('bad')

        expect {
          Rake::Builder::Autoconf::Version.new
        }.to raise_error(RuntimeError, /file.*?version.*?badly formatted/)
      end
    end
  end

  context '#decide' do
  end
end

