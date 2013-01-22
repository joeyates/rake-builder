require 'spec_helper'

describe Rake::Builder do
  include RakeBuilderHelper
  include InputOutputTestHelper

  let(:builder) { cpp_builder(:executable) }

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

  context '#primary_name' do
    it 'returns a relative path' do
      here = File.expand_path(File.dirname(__FILE__))
      target_pathname = File.join(here, 'my_prog')
      builder = cpp_builder(:executable) { |b| b.target = target_pathname }

      expect(builder.primary_name).to eq(File.join('unit', 'rake', 'my_prog'))
    end
  end

  context '#label' do
    it 'replaces dots with underscores' do
      builder = cpp_builder(:executable) { |b| b.target = 'my_prog.exe' }

      expect(builder.label).to eq('my_prog_exe')
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
    end

    it 'changes directory to the Rakefile path' do
      Dir.should_receive(:chdir).with(builder.rakefile_path)

      capturing_output do
        builder.run
      end
    end

    it 'runs the executable' do
      builder.should_receive(:system).with(builder.target, anything)

      capturing_output do
        builder.run
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

    it 'restores the preceding working directory, even after errors' do
      Dir.should_receive(:chdir).with(@old_dir)

      capturing_output do
        builder.run
      end
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
      builder = cpp_builder(:executable)

      deletes = []
      File.stub(:exist? => true)
      File.stub(:unlink) { |file| deletes << file }

      builder.clean

      expect(deletes).to eq(builder.generated_files)
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
      [:static_library, true],
      [:shared_library, true],
      [:executable,     false]
    ].each do |type, is_library|
      example type do
        expect(c_task(type).is_library?).to eq(is_library)
      end
    end
  end

  context '#source_paths' do
    it 'returns source files' do
      builder = cpp_builder(:executable)

      expect(builder.source_paths).to eq(['projects/cpp_project/main.cpp'])
    end
  end

  context '#source_files' do
    it 'finds files with the .cpp extension' do
      Rake::Path.should_receive(:find_files).with(anything, 'cpp').and_return(['a.cpp'])

      cpp_builder(:executable)
    end

    it 'should allow configuration of source extension' do
      Rake::Path.should_receive(:find_files).with(anything, 'cc').and_return(['a.cc'])

      builder = cpp_builder(:executable) do |b|
        b.source_file_extension = 'cc'
      end
    end
  end

  context '#library_dependencies_list' do
    subject { cpp_builder(:executable) { |b| b.library_dependencies = ['foo', 'bar'] } }

    it 'is a string' do
      expect(subject.library_dependencies_list).to be_a(String)
    end

    it 'lists libraries' do
      expect(subject.library_dependencies_list).to eq('-lfoo -lbar')
    end
  end
end

