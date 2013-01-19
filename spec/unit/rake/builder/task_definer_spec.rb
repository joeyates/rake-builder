require 'spec_helper'

describe Rake::Builder::TaskDefiner do
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

  def self.header_files
    ['include/file1.h']
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
  let(:builder) do
    stub(
      'Rake::Builder',
      :task_namespace => nil,
      :target_type => :executable,
      :target       => executable_target,
      :target_basename => executable_target,
      :target_prerequisites => [custom_prerequisite],
      :makedepend_file => self.class.makedepend_file,
      :source_files => self.class.source_files,
      :object_files => self.class.object_files,
      :header_files => self.class.header_files,
      :object_path  => self.class.object_files[0],
      :objects_path => objects_path,
      :generated_files => [],
      :local_config => self.class.local_config,
      :generated_headers => self.class.generated_headers,
      :install_path => 'install/path',
      :makefile_name => self.class.makefile_name,
      :default_task => :build,
    )
  end
  let(:namespaced_builder) { builder.stub(:task_namespace => 'foo'); builder }

  subject { Rake::Builder::TaskDefiner.new(builder) }

  before do
    Rake::Task.clear
  end

  context '#new' do
    it 'takes a parameter' do
      expect {
        Rake::Builder::TaskDefiner.new 
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

        expect(Rake::Task.task_defined?(task)).to be_true
      end
    end

    context 'executable' do
      it 'defines run' do
        subject.run

        expect(Rake::Task.task_defined?('run')).to be_true
      end
    end

    context 'with a namespace' do
      subject { Rake::Builder::TaskDefiner.new(namespaced_builder) }

      it 'namespaces tasks' do
        subject.run

        expect(Rake::Task.task_defined?('foo:run')).to be_true
      end

      it 'defines the namespace default task' do
        subject.run

        expect(Rake::Task.task_defined?('foo')).to be_true
      end
    end
  end

  context 'dependencies' do
    before do
      Rake::Builder::TaskDefiner.new(builder).run
    end

    [
      ['environment',       []],
      ['run',               ['build']],
      ['build',             [executable_target]],
      [executable_target,   ['environment', 'compile', custom_prerequisite]],
      ['compile',           ['environment', makedepend_file, 'load_makedepend', *object_files]],
      [objects_path,        []],
      ['src/file1.cpp',     []],
      ['include/file1.h',   []],
      [local_config,        []],
      [makedepend_file,     ['load_local_config', 'missing_headers', objects_path, *source_files, *header_files]],
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
      Rake::Builder::TaskDefiner.new(builder).run
    end

    context 'local_config' do
      it 'creates local config' do
        builder.should_receive(:create_local_config)

        Rake::Task[self.class.local_config].invoke
      end
    end

    context 'load_local_config' do
      it 'loads local config' do
        clear_prerequisites 'load_local_config'

        builder.should_receive(:load_local_config)

        Rake::Task['load_local_config'].invoke
      end
    end

    context 'missing_headers' do
      before do
        clear_prerequisites 'missing_headers'
      end

      it 'calls ensure_headers' do
        builder.should_receive(:ensure_headers)

        Rake::Task['missing_headers'].invoke
      end

      it 'fails if builder raises an error' do
        builder.stub(:ensure_headers).and_raise('foo')

        expect {
          Rake::Task['missing_headers'].invoke
        }.to raise_error
      end
    end

    context 'makedepend_file' do
      it 'creates the makedepend file' do
        clear_prerequisites self.class.makedepend_file

        builder.should_receive(:create_makedepend_file)

        Rake::Task[self.class.makedepend_file].invoke
      end
    end

    context 'load_makedepend' do
      before do
        clear_prerequisites 'load_makedepend'
        @object_file = self.class.object_files[0]
        builder.stub(:load_makedepend).and_return({@object_file => ['include/header1.h']})
      end

      it 'gets dependency information from builder' do
        builder.should_receive(:load_makedepend).and_return({@object_file => ['include/header1.h']})

        Rake::Task['load_makedepend'].invoke
      end

      it 'makes objects files depend on headers' do
        Rake::Task['load_makedepend'].invoke

        expect(Rake::Task[@object_file].prerequisites).to include('include/header1.h')
      end
    end
  end
end

