load File.dirname(__FILE__) + '/spec_helper.rb'

describe 'autoconf' do

  include RakeBuilderHelper

  before :each do
    @project = cpp_task(:executable)

    @args = Rake::TaskArguments.new(
      [:project_title, :version],
      ['my_title',     '1.0.0'],
    )
    File.stub!(:exist?).and_return(false)
    @files = {
      'VERSION'      => stub('File', :write => nil),
      'configure.ac' => stub('File', :write => nil),
      'Makefile.am'  => stub('File', :write => nil),
    }
    # Capture text saved to files
    @output = {}
    File.stub!(:open) do |(filename, perms), &block|
      file = @files[filename]
      file.stub!(:write) do |s|
        @output[filename] = s
      end
      block.call file
    end
  end

  context 'invocation' do

    it "has an 'autoconf' task" do
      task_names.include?('autoconf').
                                    should     be_true
    end

    it 'requires a project_title parameter' do
      @args = Rake::TaskArguments.new([], [])

      expect do
        Rake::Task['autoconf'].execute(@args)
      end.                          to         raise_error(RuntimeError, /supply a project_title/)
    end

    context 'version parameter' do

      it 'should be nn.nn.nn' do
        @args = Rake::TaskArguments.new(
          [:project_title, :version],
          ['my_title',     'foo'],
        )

        expect do
          Rake::Task['autoconf'].execute(@args)
        end.                          to         raise_error(RuntimeError, /The supplied version number 'foo' is badly formatted/)
      end

      context 'when missing' do

        before :each do
          @args = Rake::TaskArguments.new(
            [:project_title],
            ['my_title',   ],
          )
          File.stub(:read).with('VERSION').and_return('2.3.444')
        end

        it 'checks for a VERSION file' do
          File.should_receive(:exist?).with('VERSION').and_return(true)

          Rake::Task['autoconf'].execute(@args)
        end

        it 'fails without a VERSION file' do
          expect do
            Rake::Task['autoconf'].execute(@args)
          end.                          to         raise_error(RuntimeError, /This task requires a project version/)
        end

        context 'with a VERSION file' do

          before :each do
            File.stub(:exist?).with('VERSION').and_return(true)
          end

          it 'reads the file' do
            File.should_receive(:read).with('VERSION').and_return('2.3.444')

            Rake::Task['autoconf'].execute(@args)
          end

          it 'uses the version' do
            Rake::Task['autoconf'].execute(@args)

            @output['configure.ac'].      should     =~ /AC_INIT\(.*?, 2\.3\.444\)/
          end

        end

      end

    end

  end

  it "fails if 'configure.ac' exists" do
    File.should_receive(:exist?).with('configure.ac').and_return(true)

    expect do
      Rake::Task['autoconf'].execute(@args)
    end.                          to         raise_error(RuntimeError, /'configure.ac' already exists/)
  end

  it "fails if 'Makefile.am' exists" do
    File.should_receive(:exist?).with('Makefile.am').and_return(true)

    expect do
      Rake::Task['autoconf'].execute(@args)
    end.                          to         raise_error(RuntimeError, /'Makefile.am' already exists/)
  end

  context 'configure.ac' do

    it 'is created' do
      File.                       should_receive(:open).
                                  with('configure.ac', 'w')

      Rake::Task['autoconf'].execute(@args)
    end

    it 'has the title' do
      Rake::Task['autoconf'].execute(@args)

      @output['configure.ac'].      should     =~ /AC_INIT\(my_title, /
    end

    it 'has the version' do
      Rake::Task['autoconf'].execute(@args)

      @output['configure.ac'].      should     =~ /AC_INIT\(.*?, 1\.0\.0\)/
    end

    it 'checks for a source file' do
      Rake::Task['autoconf'].execute(@args)

      @output['configure.ac'].      should     =~ /AC_CONFIG_SRCDIR\(\[cpp_project\/main\.cpp\]\)/
    end

    it 'references the Makefile' do
      Rake::Task['autoconf'].execute(@args)

      @output['configure.ac'].      should     =~ /AC_CONFIG_FILES\(\[Makefile\]\)/
    end

  end

  context 'Makefile.am' do
    it 'is created' do
      Rake::Builder.should_receive(:create_autoconf)

      Rake::Task['autoconf'].execute(@args)
    end
  end
end

