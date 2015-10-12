require 'spec_helper'

describe Rake::Builder do
  include InputOutputTestHelper
  
  let(:target_path) { File.join('foo', 'bar') }
  let(:target_pathname) { File.join(target_path, 'my_prog.exe') }
  let(:source_paths) { ['src/file1.cpp'] }
  let(:target_parameters) { [] }
  let(:builder) do
    Rake::Builder.new do |b|
      b.target               = target_pathname
      b.library_dependencies = ['foo', 'bar']
      b.target_parameters    = target_parameters
    end
  end
  let(:installer) do
    double(Rake::Builder::Installer, install: nil, uninstall: nil)
  end

  before do
    allow(Rake::Path).to receive(:find_files) { source_paths }
    allow(builder).to receive(:system)
  end

  context '.create_autoconf' do
    let(:version) { double('Rake::Builder::Autoconf::Autoconf::Version', :decide => 'qux') }
    let(:presenter) { double('Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter', :save => nil) }
    let(:configure_ac) { double('Rake::Builder::ConfigureAc', :save => nil) }

    before do
      allow(Rake::Builder::Autoconf::Version).to receive(:new) { version }
      allow(File).to receive(:exist?).with('configure.ac') { false }
      allow(File).to receive(:exist?).with('Makefile.am') { false }
      allow(Rake::Builder::ConfigureAc).to receive(:new) { configure_ac }
      allow(Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter).to receive(:new) { presenter }
    end

    it 'fails if project_title is nil' do
      expect {
        Rake::Builder.create_autoconf(nil, 'bar', 'baz')
      }.to raise_error(RuntimeError, 'Please supply a project_title parameter')
    end

    context 'if Version fails' do
      before do
        allow(Rake::Builder::Autoconf::Version).to receive(:new).and_raise('foo')
      end

      it 'fails' do
        expect {
          Rake::Builder.create_autoconf('foo', 'bar', 'baz')
        }.to raise_error(RuntimeError, 'foo')
      end
    end

    it 'fails if configure.ac exists' do
      allow(File).to receive(:exist?).with('configure.ac') { true }

      expect {
        Rake::Builder.create_autoconf('foo', 'bar', 'baz')
      }.to raise_error(RuntimeError, "The file 'configure.ac' already exists")
    end

    it 'fails if Makefile.am exists' do
      allow(File).to receive(:exist?).with('Makefile.am') { true }

      expect {
        Rake::Builder.create_autoconf('foo', 'bar', 'baz')
      }.to raise_error(RuntimeError, "The file 'Makefile.am' already exists")
    end

    it 'creates configure.ac' do
      allow(Rake::Builder::ConfigureAc).to receive(:new) { configure_ac }

      Rake::Builder.create_autoconf('foo', 'bar', 'baz')
    end

    it 'creates Makefile.am' do
      allow(Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter).to receive(:new) { presenter }

      Rake::Builder.create_autoconf('foo', 'bar', 'baz')
    end
  end

  context '.new' do
    it 'fails without a block' do
      expect {
        Rake::Builder.new
      }.to raise_error(RuntimeError, 'No block given')
    end

    it 'raises an error when the target is an empty string' do
      expect {
        Rake::Builder.new { |b| b.target = '' }
      }.to raise_error(Rake::Builder::Error, 'The target name cannot be an empty string')
    end

    it 'raises an error when the target is nil' do
      expect {
        Rake::Builder.new { |b| b.target = nil }
      }.to raise_error(Rake::Builder::Error, 'The target name cannot be nil')
    end

    it 'raises an error when the supplied target_type is unknown' do
      expect {
        Rake::Builder.new { |b| b.target_type = :foo }
      }.to raise_error(Rake::Builder::Error, 'Building foo targets is not supported')
    end

    it 'remembers the Rakefile path' do
      allow(Rake::Path).to receive(:find_files) { ['main.cpp'] }
      here = File.dirname(File.expand_path(__FILE__))

      builder = Rake::Builder.new {}

      expect(builder.rakefile_path).to eq(here)
    end
  end

  context '#build' do
    before do
      @target_exists = [false, true]
      allow(File).to receive(:exist?).with(builder.target) { @target_exists.shift }
      `(exit 0)` # set $? to a successful Process::Status
    end

    it 'checks if the old target exists' do
      allow(File).to receive(:exist?).with(builder.target) { @target_exists.shift }

      builder.build
    end

    it 'deletes the old target' do
      @target_exists = [true, true]

      allow(File).to receive(:unlink).with(builder.target)

      builder.build
    end

    it 'fails if a build command fails' do
      `(exit 1)` # set $? to a failing Process::Status

      expect {
        builder.build
      }.to raise_error(Rake::Builder::BuildFailure, /command.*?failed/)
    end

    it 'fails if the target is missing afterwards' do
      @target_exists = [false, false]

      expect {
        builder.build
      }.to raise_error(Rake::Builder::BuildFailure, /not created/)
    end
  end

  context '#run' do
    before do
      @old_dir = Dir.pwd
      allow(Dir).to receive(:chdir).with(builder.rakefile_path)
      allow(Dir).to receive(:chdir).with(@old_dir)
      # Run a successful command, so Process:Status $? gets set to success
      `ls`
    end

    it 'changes directory to the Rakefile path' do
      allow(Dir).to receive(:chdir).with(builder.rakefile_path)

      capturing_output do
        builder.run
      end
    end

    it 'runs the executable' do
      capturing_output do
        builder.run
      end

      expect(builder).to have_received(:system).with('./' + builder.target, anything)
    end

    context 'target_parameters' do
      let(:target_parameters) { %w(--ciao) }

      it 'are passed as command line options to the target' do
        capturing_output do
          builder.run
        end

        expect(builder).to have_received(:system).with("./#{builder.target} --ciao", anything)
      end
    end

    it 'outputs the stdout results, then the stderr results' do
      allow(builder).to receive(:system) do |command|
        $stdout.puts 'standard output'
        $stderr.puts 'error output'
      end

      stdout, stderr = capturing_output do
        builder.run
      end

      expect(stdout).to eq("standard output\n")
      expect(stderr).to eq("error output\n")
    end

    it 'raises and error is the program does not run successfully' do
      allow(builder).to receive(:system) { `(exit 1)` } # set $? to a failing Process::Status

      expect {
        builder.run
      }.to raise_error(Exception, /Running.*?failed with status 1/)
    end

    it 'restores the preceding working directory, even after errors' do
      allow(builder).to receive(:system).and_raise('foo')

      builder.run rescue nil

      expect(Dir).to have_received(:chdir).with(@old_dir)
    end
  end

  context '#clean' do
    it 'checks if files exist' do
      exists = []
      allow(File).to receive(:exist?) { |file| exists << file; false }

      builder.clean

      expect(exists).to eq(builder.generated_files)
    end

    it 'deletes generated files' do
      deletes = []
      allow(File).to receive(:exist?) { true }
      allow(File).to receive(:unlink) { |file| deletes << file }

      builder.clean

      expect(deletes).to eq(builder.generated_files)
    end
  end

  context '#header_search_paths' do
    it 'is deprecated' do
      stdout, stderr = capturing_output do
        builder.header_search_paths
      end

      expect(stderr).to include('Deprecation notice')
    end
  end

  context '#header_search_paths=' do
    it 'is deprecated' do
      stdout, stderr = capturing_output do
        builder.header_search_paths = []
      end

      expect(stderr).to include('Deprecation notice')
    end
  end

  context '#target' do
    it "defaults to 'a.out'" do
      allow(Rake::Path).to receive(:find_files) { ['main.cpp'] }

      builder = Rake::Builder.new {}

      expect(builder.target).to end_with('/a.out')
    end
  end

  context '#label' do
    it 'replaces dots with underscores' do
      expect(builder.label).to eq(File.join('foo', 'bar', 'my_prog_exe'))
    end

    context 'a leading current directory indicator' do
      let(:target_path) { File.join('.', 'ciao') }

      it 'is removed' do
        expect(builder.label).to eq(File.join('ciao', 'my_prog_exe'))
      end
    end
  end

  context '#target_type' do
    [
      ['my_program',   :executable],
      ['libstatic.a',  :static_library],
      ['libshared.so', :shared_library],
    ].each do |name, type|
      it "recognises '#{name}' as '#{type}'" do
        allow(Rake::Path).to receive(:find_files) { ['file'] }

        builder = Rake::Builder.new { |b| b.target = name }

        expect(builder.target_type).to eq(type)
      end
    end
  end

  context '#is_library?' do
    [
      [:static_library, 'libbaz.a',  true],
      [:shared_library, 'libfoo.so', true],
      [:executable,     'baz',       false]
    ].each do |type, target, is_library|
      example type do
        builder = Rake::Builder.new do |b|
          b.target = target
        end
        expect(builder.is_library?).to eq(is_library)
      end
    end
  end

  context '#source_files' do
    it 'finds files with the .cpp extension' do
      allow(Rake::Path).to receive(:find_files).with(anything, 'cpp') { ['a.cpp'] }

      builder
    end

    it 'should allow configuration of source extension' do
      Rake::Builder.new do |b|
        b.source_file_extension = 'cc'
      end

      expect(Rake::Path).to have_received(:find_files).with(anything, 'cc') { ['a.cc'] }
    end
  end

  context '#object_path' do
    let(:source_path) { 'foo/bar/baz.cpp' }

    subject { builder.object_path(source_path) }

    it 'substitutes the source extension with the object one' do
      expect(subject).to end_with('.o')
    end

    it 'adds the objects path' do
      expect(subject).to start_with(builder.objects_path)
    end
  end

  context '#library_dependencies_list' do
    it 'is a string' do
      expect(builder.library_dependencies_list).to be_a(String)
    end

    it 'lists libraries' do
      expect(builder.library_dependencies_list).to eq('-lfoo -lbar')
    end
  end

  context '#create_makedepend_file' do
    before do
      allow(builder).to receive(:system).with('which makedepend >/dev/null') do
        `(exit 0)` # set $? to a successful Process::Status
      end

      allow(builder).to receive(:system).with(/makedepend -f-/, anything)
    end

    it 'fails if makedepend is missing' do
      allow(builder).to receive(:system).with('which makedepend >/dev/null') do
        `(exit 1)` # set $? to a successful Process::Status
      end

      expect {
        builder.create_makedepend_file
      }.to raise_error(RuntimeError, 'makedepend not found')
    end

    it 'calls makedepend' do
      builder.create_makedepend_file

      expect(builder).to have_received(:system).with(/makedepend -f-/, anything)
    end
  end

  context '#load_makedepend' do
    let(:content) do
      lines = []
      lines << 'Some text'
      builder.source_files.each do |f|
        source_path_object = f.gsub(/\.[^\.]+$/, '.o')
        lines << source_path_object + ': header1.h'
      end
      lines.join("\n")
    end

    before do
      allow(File).to receive(:read).with(builder.makedepend_file) { content }
    end

    it 'returns a map of sources to headers' do
      expected = builder.object_files.reduce({}) do |a, e|
        a[e] = ['header1.h']
        a
      end

      expect(builder.load_makedepend).to eq(expected)
    end
  end

  context '#load_local_config' do
    let(:config_include_paths) { ['/path/one', '/path/two'] }
    let(:config_compilation_options) { ['opt1', 'opt2'] }
    let(:local_config) do
      double(
        'Rake::Builder::LocalConfig',
        :load => nil,
        :include_paths => config_include_paths,
        :compilation_options => config_compilation_options,
      )
    end

    before { allow(Rake::Builder::LocalConfig).to receive(:new) { local_config } }

    it 'loads local config' do
      allow(Rake::Builder::LocalConfig).to receive(:new).
        with(/\.rake-builder/) { local_config }

      builder.load_local_config

      expect(local_config).to have_received(:load).with(no_args)
    end

    it 'adds include paths' do
      original = builder.include_paths.clone

      builder.load_local_config

      expect(builder.include_paths).to eq(original + config_include_paths)
    end

    it 'adds compilation options' do
      original = builder.compilation_options.clone

      builder.load_local_config

      expect(builder.compilation_options).to eq(original + config_compilation_options)
    end
  end

  context '#create_local_config' do
    let(:compiler) do
      double(
        'Compiler',
        :default_include_paths => [],
        :missing_headers       => [],
        :include_paths         => [],
      )
    end
    let(:local_config) do
      double(
        'Rake::Builder::LocalConfig',
        :include_paths=        => nil,
        :save                  => nil
      )
    end

    before do
      allow(Compiler::Base).to receive(:for).with(:gcc) { compiler }
      allow(Rake::Builder::LocalConfig).to receive(:new) { local_config }
    end

    it 'saves a LocalConfig' do
      builder.create_local_config

      expect(local_config).to have_received(:save)
    end
  end

  context '#install' do
    before { allow(Rake::Builder::Installer).to receive(:new) { installer } }

    it 'installs the target' do
      builder.install

      expect(Rake::Builder::Installer).to have_received(:new) { installer }
    end

    it 'installs headers for static libraries' do
      allow(File).to receive(:file?).with('header.h') { true }

      builder = Rake::Builder.new do |b|
        b.target              = 'libthe_static_library.a'
        b.installable_headers = ['header.h']
      end

      builder.install

      expect(installer).to have_received(:install).with(builder.target, anything)
      expect(installer).to have_received(:install).with('header.h', anything)
    end
  end

  context '#uninstall' do
    before { allow(Rake::Builder::Installer).to receive(:new) { installer } }

    it 'uninstalls' do
      installed_path = File.join(builder.install_path, builder.target_basename)

      builder.uninstall

      expect(installer).to have_received(:uninstall).with(installed_path)
    end
  end
end
