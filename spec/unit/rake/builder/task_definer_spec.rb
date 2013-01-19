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

  def self.custom_prerequisite
    'custom_prerequisite'
  end

  def self.project_files
    source_files + ['include/file1.h']
  end

  def self.generated_headers
    ['config.h']
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
      :object_path  => self.class.object_files[0],
      :objects_path => objects_path,
      :generated_files => [],
      :local_config => self.class.local_config,
      :project_files => self.class.project_files,
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
      [local_config,        []],
      [makedepend_file,     ['load_local_config', 'missing_headers', objects_path, *project_files]],
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
      it 'depend on source files'
      it 'depend on headers'
    end

    context 'compilation' do
      it 'fails if there are missing headers'
      it 'is needed if a source file changes' # this check *should* be redundant if 'object files' dependencies work
      it 'is needed if a header changes' # this check *should* be redundant if 'object files' dependencies work
    end
  end

  context 'tasks' do
    it 'runs builder tasks'
  end
end

