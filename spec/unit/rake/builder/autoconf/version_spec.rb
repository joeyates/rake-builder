require 'spec_helper'

describe Rake::Builder::Autoconf::Version do
  let(:exists) { true }
  let(:file_content) { '1.2.3' }
  before do
    allow(File).to receive(:exist?).with('VERSION') { exists }
    allow(File).to receive(:read).with('VERSION') { file_content }
  end
  let(:params) { [] }
  let(:parameter_version) { '4.5.6' }

  subject { described_class.new(*params) }

  context '.new' do
    context 'with parameter' do
      it 'fails if the version parameter is not nn.nn.nn' do
        expect {
          described_class.new('hello')
        }.to raise_error(RuntimeError, /badly formatted/)
      end
    end

    context 'without parameter' do
      it 'succeeds' do
        described_class.new
      end
    end

    context 'if the version is badly formed' do
      let(:file_content) { 'bad' }

      it 'fails' do
        expect {
          described_class.new
        }.to raise_error(RuntimeError, /file.*?version.*?badly formatted/)
      end
    end
  end

  context '#decide' do
    let(:file) { double(File, write: nil) }

    before do
      allow(File).to receive(:open).with('VERSION', 'w').and_yield(file)
    end

    context 'disk file is absent' do
      let(:exists) { false }

      context 'parameter is nil' do
        it 'raises an error' do
          expect {
            subject.decide
          }.to raise_error(RuntimeError, /Please do one of the following/)
        end
      end

      context 'parameter not nil' do
        let(:params) { [parameter_version] }

        it 'saves the version' do
          subject.decide

          expect(file).to have_received(:write).with(parameter_version + "\n")
        end

        it 'returns the parameter version' do
          expect(subject.decide).to eq(parameter_version)
        end
      end
    end

    context 'disk file exists' do
      let(:exists) { true }

      context 'without parameters' do
        it 'returns the file version from disk' do
          expect(subject.decide).to eq(file_content)
        end
      end

      context 'parameter not nil' do
        context 'if the two versions differ'do
          let(:params) { [parameter_version] }

          it 'fails' do
            expect {
              subject.decide
            }.to raise_error(RuntimeError, /parameter.*?is different to.*?VERSION/)
          end
        end

        context 'if the two versions are the same' do
          let(:params) { [file_content] }

          it 'returns the version' do
            expect(subject.decide).to eq(file_content)
          end
        end
      end
    end
  end
end
