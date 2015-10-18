require 'spec_helper'

describe Rake::Builder::BuilderTaskDefiner do
  def self.executable_target
    'executable_target'
  end

  def self.objects_path
    '/path/to/object/files'
  end

  def self.local_config
    'local_config'
  end

  def self.makedepend_file
    'makedepend_file'
  end

  def self.makefile_name
    'Makefile'
  end

  def self.source_files
    ['src/file1.cpp']
  end

  def self.object_files
    ['src/file1.o']
  end

  def self.custom_prerequisite
    'custom_prerequisite'
  end

  def self.generated_headers
    ['config.h']
  end

  def clear_prerequisites(task)
    Rake::Task[task].instance_variable_set('@prerequisites', [])
  end

  let(:executable_target) { self.class.executable_target }
  let(:objects_path) { self.class.objects_path }
  let(:custom_prerequisite) { self.class.custom_prerequisite }
  let(:logger) { double(Logger, :'level=' => nil) }
  let(:builder) do
    double(
      Rake::Builder,
      task_namespace:       task_namespace,
      target_type:          :executable,
      target:               executable_target,
      target_basename:      executable_target,
      target_prerequisites: [custom_prerequisite],
      makedepend_file:      self.class.makedepend_file,
      source_files:         self.class.source_files,
      object_files:         self.class.object_files,
      object_path:          self.class.object_files[0],
      objects_path:         objects_path,
      generated_files:      [],
      local_config:         self.class.local_config,
      generated_headers:    self.class.generated_headers,
      install_path:         'install/path',
      makefile_name:        self.class.makefile_name,
      default_task:         :build,
      logger:               logger,
    )
  end
  let(:task_namespace) { nil }

  subject { described_class.new(builder) }

  before do
    Rake::Task.clear
    %w(
      run clean build install uninstall compile
      create_makedepend_file create_local_config ensure_headers
      load_local_config
    ).each do |m|
      allow(builder).to receive(m.intern)
    end
  end

  context '#new' do
    it 'takes a parameter' do
      expect {
        described_class.new
      }.to raise_error(ArgumentError)
    end
  end

  context '#run' do
    [
      'default',
      'environment',
      'build',
      executable_target,
      'compile',
      objects_path,
      local_config,
      makedepend_file,
      'load_local_config',
      'missing_headers',
      'load_makedepend',
      'clean',
      'install',
      'uninstall',
      makefile_name,
      *object_files
    ].each do |task|
      it "defines '#{task}'" do
        subject.run

        expect(Rake::Task.task_defined?(task)).to be_truthy
      end
    end

    context 'executable' do
      it 'defines run' do
        subject.run

        expect(Rake::Task.task_defined?('run')).to be_truthy
      end
    end

    context 'with a namespace' do
      let(:task_namespace) { 'foo' }

      it 'namespaces tasks' do
        subject.run

        expect(Rake::Task.task_defined?('foo:run')).to be_truthy
      end

      it 'defines the namespace default task' do
        subject.run

        expect(Rake::Task.task_defined?('foo')).to be_truthy
      end

      it 'does not fiddle up the local_config file' do
        subject.run

        expect(Rake::Task['foo:load_local_config'].prerequisites).to eq([builder.local_config])
      end
    end
  end

  context 'dependencies' do
    before do
      described_class.new(builder).run
    end

    [
      ['environment',       []],
      ['run',               ['build']],
      ['build',             ['compile', executable_target]],
      [executable_target,   ['environment', 'compile', custom_prerequisite, *object_files]],
      ['compile',           ['environment', makedepend_file, 'load_makedepend', *object_files]],
      [objects_path,        []],
      ['src/file1.cpp',     []],
      [local_config,        []],
      [makedepend_file,     ['load_local_config', 'missing_headers', objects_path, *source_files]],
      ['load_local_config', [local_config]],
      ['missing_headers',   generated_headers],
      ['load_makedepend',   [makedepend_file]],
      ['clean',             []],
      ['install',           ['build']],
      ['uninstall',         []],
      [makefile_name,       [makedepend_file, 'load_makedepend']],
    ].each do |task, expected|
      example task do
        expect(Rake::Task[task].prerequisites).to eq(expected)
      end
    end

    context 'object files' do
      it 'depend on source files' do
        expect(Rake::Task[self.class.object_files[0]].prerequisites).to include('src/file1.cpp')
      end
    end
  end

  context 'tasks' do
    before do
      described_class.new(builder).run
    end

    [
      ['run', 'runs the builder', :run],
      [executable_target, 'builds the target', :build],
      ['clean', 'cleans the build', :clean],
      ['install', 'installs the target', :install],
      ['uninstall', 'uninstalls the target', :uninstall],
      ['load_local_config', 'loads local config', :load_local_config],
    ].each do |task, action, command|
      context task do
        it action do
          clear_prerequisites task

          Rake::Task[task].invoke

          expect(builder).to have_received(command)
        end
      end
    end

    context 'compile file' do
      it 'compiles the file' do
        clear_prerequisites 'src/file1.o'

        Rake::Task['src/file1.o'].invoke


        expect(builder).to have_received(:compile).
          with('src/file1.cpp', 'src/file1.o')
      end
    end

    context 'local_config' do
      it 'creates local config' do
        Rake::Task[self.class.local_config].invoke

        expect(builder).to have_received(:create_local_config)
      end
    end

    context 'missing_headers' do
      before do
        clear_prerequisites 'missing_headers'
      end

      it 'calls ensure_headers' do
        Rake::Task['missing_headers'].invoke

        expect(builder).to have_received(:ensure_headers)
      end

      it 'fails if builder raises an error' do
        allow(builder).to receive(:ensure_headers).and_raise('foo')

        expect {
          Rake::Task['missing_headers'].invoke
        }.to raise_error(RuntimeError, /foo/)
      end
    end

    context 'makedepend_file' do
      it 'creates the makedepend file' do
        clear_prerequisites self.class.makedepend_file

        Rake::Task[self.class.makedepend_file].invoke

        expect(builder).to have_received(:create_makedepend_file)
      end
    end

    context 'load_makedepend' do
      before do
        clear_prerequisites 'load_makedepend'
        @object_file = self.class.object_files[0]
        allow(builder).to receive(:load_makedepend) { {@object_file => ['include/header1.h']} }
      end

      it 'creates tasks for headers' do
        Rake::Task['load_makedepend'].invoke

        expect(Rake.application.lookup('include/header1.h')).to be_a(Rake::Task)
      end

      it 'makes objects files depend on headers' do
        Rake::Task['load_makedepend'].invoke

        expect(Rake::Task[@object_file].prerequisites).to include('include/header1.h')
      end
    end

    context 'makefile' do
      let(:presenter) do
        double(Rake::Builder::Presenters::Makefile::BuilderPresenter, save: nil)
      end

      before do
        allow(Rake::Builder::Presenters::Makefile::BuilderPresenter).to receive(:new).with(builder) { presenter }
      end

      it 'creates a makefile' do
        clear_prerequisites self.class.makefile_name

        Rake::Task[self.class.makefile_name].invoke

        expect(presenter).to have_received(:save)
      end
    end

    context 'environment' do
      it 'sets the logger level if required' do
        ENV['DEBUG'] = 'true'

        Rake::Task['environment'].invoke

        expect(logger).to have_received(:level=).with(0)
      end
    end
  end
end

