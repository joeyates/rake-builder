require 'spec_helper'

describe Rake::Builder::Autoconf::Version do
  before do
    File.stub(:exist? => true)
    File.stub(:read   => '1.2.3')
  end

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
    let(:with_parameter) { Rake::Builder::Autoconf::Version.new('4.5.6') }
    let(:without_parameter) { Rake::Builder::Autoconf::Version.new }

    before { File.stub(:open).with('VERSION', 'w') }

    context 'file version is nil' do
      before { File.stub(:exist? => false) }

      context 'parameter is nil' do
        it 'raises an error' do
          expect {
            without_parameter.decide
          }.to raise_error(RuntimeError, /Please do one of the following/)
        end
      end

      context 'parameter not nil' do
        it 'saves the version' do
          File.should_receive(:open).with('VERSION', 'w')

          with_parameter.decide
        end

        it 'returns the parameter version' do
          expect(with_parameter.decide).to eq('4.5.6')
        end
      end
    end

    context 'file version not nil' do
      before do
        File.stub(:exist? => true)
        File.stub(:read).with('VERSION').and_return("6.6.6\n")
      end

      context 'parameter is nil' do
        it 'returns the file version' do
          expect(without_parameter.decide).to eq('6.6.6')
        end
      end

      context 'parameter not nil' do
        it 'fails if the two versions differ'do
          File.should_receive(:read).with('VERSION').and_return("6.6.6\n")

          expect {
            with_parameter.decide
          }.to raise_error(RuntimeError, /parameter.*?is different to.*?VERSION/)
        end

        it 'returns the version' do
          File.should_receive(:read).with('VERSION').and_return("4.5.6\n")

          expect(with_parameter.decide).to eq('4.5.6')
        end
      end
    end
  end
end

