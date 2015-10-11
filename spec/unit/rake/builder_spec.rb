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
    stub(
      'Rake::Builder::Installer',
      :install => nil
    )
  end

  before do
    Rake::Path.stub(:find_files).and_return(source_paths)
  end

  context '.create_autoconf' do
    let(:version) { stub('Rake::Builder::Autoconf::Autoconf::Version', :decide => 'qux') }
    let(:presenter) { stub('Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter', :save => nil) }
    let(:configure_ac) { stub('Rake::Builder::ConfigureAc', :save => nil) }

    before do
      Rake::Builder::Autoconf::Version.stub(:new).and_return(version)
      File.stub(:exist?).with('configure.ac').and_return(false)
      File.stub(:exist?).with('Makefile.am').and_return(false)
      Rake::Builder::ConfigureAc.stub(:new => configure_ac)
      Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter.stub(:new).and_return(presenter)
    end

    it 'fails if project_title is nil' do
      expect {
        Rake::Builder.create_autoconf(nil, 'bar', 'baz')
      }.to raise_error(RuntimeError, 'Please supply a project_title parameter')
    end

    it 'fails if Version fails' do
      Rake::Builder::Autoconf::Version.stub(:new).and_raise('foo')

      expect {
        Rake::Builder.create_autoconf('foo', 'bar', 'baz')
      }.to raise_error(RuntimeError, 'foo')
    end

    it 'fails if configure.ac exists' do
      File.should_receive(:exist?).with('configure.ac').and_return(true)

      expect {
        Rake::Builder.create_autoconf('foo', 'bar', 'baz')
      }.to raise_error(RuntimeError, "The file 'configure.ac' already exists")
    end

    it 'fails if Makefile.am exists' do
      File.should_receive(:exist?).with('Makefile.am').and_return(true)

      expect {
        Rake::Builder.create_autoconf('foo', 'bar', 'baz')
      }.to raise_error(RuntimeError, "The file 'Makefile.am' already exists")
    end

    it 'creates configure.ac' do
      Rake::Builder::ConfigureAc.should_receive(:new).and_return(configure_ac)

      Rake::Builder.create_autoconf('foo', 'bar', 'baz')
    end

    it 'creates Makefile.am' do
      Rake::Builder::Presenters::MakefileAm::BuilderCollectionPresenter.should_receive(:new).and_return(presenter)

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
      Rake::Path.stub(:find_files => ['main.cpp'])
      here = File.dirname(File.expand_path(__FILE__))

      builder = Rake::Builder.new {}

      expect(builder.rakefile_path).to eq(here)
    end
  end

  context '#build' do
    before do
      @target_exists = [false, true]
      File.stub(:exist?).with(builder.target) { @target_exists.shift }
      builder.stub(:system => nil)
      `(exit 0)` # set $? to a successful Process::Status
    end

    it 'checks if the old target exists' do
      File.should_receive(:exist?).with(builder.target) { @target_exists.shift }

      builder.build
    end

    it 'deletes the old target' do
      @target_exists = [true, true]

      File.should_receive(:unlink).with(builder.target)

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
      Dir.stub(:chdir).with(builder.rakefile_path)
      builder.stub(:system)
      Dir.stub(:chdir).with(@old_dir)
      # Run a successful command, so Process:Status $? gets set to success
      `ls`
    end

    it 'changes directory to the Rakefile path' do
      Dir.should_receive(:chdir).with(builder.rakefile_path)

      capturing_output do
        builder.run
      end
    end

    it 'runs the executable' do
      builder.should_receive(:system).with('./' + builder.target, anything)

      capturing_output do
        builder.run
      end
    end

    context 'target_parameters' do
      let(:target_parameters) { %w(--ciao) }

      it 'are passed as command line options to the target' do
        builder.should_receive(:system).with("./#{builder.target} --ciao", anything)

        capturing_output do
          builder.run
        end
      end
    end

    it 'outputs the stdout results, then the stderr results' do
      builder.stub(:system) do |command|
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
      builder.stub(:system) { `(exit 1)` } # set $? to a failing Process::Status

      expect {
        builder.run
      }.to raise_error(Exception, /Running.*?failed with status 1/)
    end

    it 'restores the preceding working directory, even after errors' do
      builder.stub(:system).and_raise('foo')

      Dir.should_receive(:chdir).with(@old_dir)

      builder.run rescue nil
    end
  end

  context '#clean' do
    it 'checks if files exist' do
      exists = []
      File.stub(:exist?) { |file| exists << file; false }

      builder.clean

      expect(exists).to eq(builder.generated_files)
    end

    it 'deletes generated files' do
      deletes = []
      File.stub(:exist? => true)
      File.stub(:unlink) { |file| deletes << file }

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
      Rake::Path.stub(:find_files => ['main.cpp'])

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
        Rake::Path.stub(:find_files).and_return(['file'])

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
      Rake::Path.should_receive(:find_files).with(anything, 'cpp').and_return(['a.cpp'])

      builder
    end

    it 'should allow configuration of source extension' do
      Rake::Path.should_receive(:find_files).with(anything, 'cc').and_return(['a.cc'])

      Rake::Builder.new do |b|
        b.source_file_extension = 'cc'
      end
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
      builder.stub(:system).with('which makedepend >/dev/null') do
        `(exit 0)` # set $? to a successful Process::Status
      end

      builder.stub(:system).with(/makedepend -f-/, anything)
    end

    it 'fails if makedepend is missing' do
      builder.stub(:system).with('which makedepend >/dev/null') do
        `(exit 1)` # set $? to a successful Process::Status
      end

      expect {
        builder.create_makedepend_file
      }.to raise_error(RuntimeError, 'makedepend not found')
    end

    it 'calls makedepend' do
      builder.should_receive(:system).with(/makedepend -f-/, anything)

      builder.create_makedepend_file
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
      File.stub(:read).with(builder.makedepend_file).and_return(content)
    end

    it 'opens the file' do
      File.should_receive(:read).with(builder.makedepend_file).and_return(content)

      builder.load_makedepend
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
      stub(
        'Rake::Builder::LocalConfig',
        :load => nil,
        :include_paths => config_include_paths,
        :compilation_options => config_compilation_options,
      )
    end

    before { Rake::Builder::LocalConfig.stub(:new => local_config) }

    it 'loads local config' do
      Rake::Builder::LocalConfig.should_receive(:new).
        with(/\.rake-builder/).and_return(local_config)
      local_config.should_receive(:load).with()

      builder.load_local_config
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
      stub(
        'Compiler',
        :default_include_paths => [],
        :missing_headers       => [],
        :include_paths         => [],
      )
    end
    let(:local_config) do
      stub(
        'Rake::Builder::LocalConfig',
        :include_paths=        => nil,
        :save                  => nil
      )
    end

    before do
      Compiler::Base.stub(:for).with(:gcc).and_return(compiler)
      Rake::Builder::LocalConfig.stub(:new).and_return(local_config)
    end

    it 'gets extra paths for missing headers' do
      compiler.should_receive(:missing_headers).
        with(['./include'], source_paths).
        and_return([])

      builder.create_local_config
    end

    it 'saves a LocalConfig' do
      local_config.should_receive(:save)

      builder.create_local_config
    end
  end

  context '#install' do
    before { Rake::Builder::Installer.stub(:new).and_return(installer) }

    it 'installs the target' do
      Rake::Builder::Installer.should_receive(:new).and_return(installer)
      installer.should_receive(:install).with(builder.target, anything)

      builder.install
    end

    it 'installs headers for static libraries' do
      installer.stub(:install).with(builder.target, anything)
      File.should_receive(:file?).with('header.h').and_return(true)
      installer.should_receive(:install).with('header.h', anything)

      builder = Rake::Builder.new do |b|
        b.target              = 'libthe_static_library.a'
        b.installable_headers = ['header.h']
      end

      builder.install
    end
  end

  context '#uninstall' do
    before { Rake::Builder::Installer.stub(:new).and_return(installer) }

    it 'uninstalls' do
      installed_path = File.join(builder.install_path, builder.target_basename)
      installer.should_receive(:uninstall).with(installed_path)

      builder.uninstall
    end
  end
end

