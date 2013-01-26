require 'spec_helper'

describe Rake::Builder::Presenters::Makefile::BuilderPresenter do
  def self.compiler; 'the_compiler'; end
  def self.compiler_flags; 'the_compiler_flags'; end
  def self.linker; 'the_linker'; end
  def self.link_flags; 'the_link_flags'; end
  def self.objects_path; '/objects'; end

  let(:executable_target) { 'the_executable' }
  let(:shared_library_target) { 'libshared.so' }
  let(:static_library_target) { 'libstatic.a' }
  let(:label) { 'the_label' }
  let(:source_files) { ['/sources/one.c', '/sources/two.c'] }
  let(:object_files) { ['/objects/one.o', '/objects/two.o'] }
  let(:makefile_name) { 'the_makefile' }
  let(:common_attributes) do
    {
      :label => label,
      :compiler => self.class.compiler,
      :compiler_flags => self.class.compiler_flags,
      :linker => self.class.linker,
      :link_flags => self.class.link_flags,
      :objects_path => self.class.objects_path,
      :source_files => source_files,
      :object_files => object_files,
      :makefile_name => makefile_name,
    }
  end
  let(:executable_attributes) do
    common_attributes.merge(
      :target => executable_target,
      :target_type => :executable,
    )
  end
  let(:static_library_attributes) do
    common_attributes.merge(
      :target => static_library_target,
      :target_type => :static_library,
    )
  end
  let(:shared_library_attributes) do
    common_attributes.merge(
      :target => shared_library_target,
      :target_type => :shared_library,
    )
  end
  
  let(:executable_builder) { stub('Rake::Builder', executable_attributes) }
  let(:static_library_builder) { stub('Rake::Builder', static_library_attributes) }
  let(:shared_library_builder) { stub('Rake::Builder', shared_library_attributes) }

  let(:executable_subject) { Rake::Builder::Presenters::Makefile::BuilderPresenter.new(executable_builder) }
  let(:static_library_subject) { Rake::Builder::Presenters::Makefile::BuilderPresenter.new(static_library_builder) }
  let(:shared_library_subject) { Rake::Builder::Presenters::Makefile::BuilderPresenter.new(shared_library_builder) }

  context '.new' do
    it 'takes one parameter' do
      expect {
        Rake::Builder::Presenters::Makefile::BuilderPresenter.new
      }.to raise_error(ArgumentError, /wrong number of arguments/)
    end

    it 'fails with unknown target types' do
    end
  end

  context '#to_s' do
    it 'fails with unknown target types' do
      executable_builder.should_receive(:target_type).any_number_of_times.and_return(:foo)

      expect {
        Rake::Builder::Presenters::Makefile::BuilderPresenter.new(executable_builder)
      }.to raise_error(RuntimeError, /Unknown.*?target type/)
    end

    context 'target' do
      context 'for executable' do
        it 'is executable' do
          expect(executable_subject.to_s).to include("EXECUTABLE_TARGET = #{executable_target}")
        end
      end

      context 'for library' do
        it 'is a library' do
          expect(static_library_subject.to_s).to include("LIB_TARGET = #{static_library_target}")
        end
      end
    end

    context 'variables' do
      [
        ['COMPILER', compiler],
        ['COMPILER_FLAGS', compiler_flags],
        ['LINKER', linker],
        ['LINK_FLAGS', link_flags],
        ['OBJECT_DIR', objects_path],
      ].each do |name, value|
        it "declares '#{name}'" do
          expect(executable_subject.to_s).to match(/#{name}\s+=\s+#{value}/)
        end
      end

      it "declares 'OBJECTS'" do
        expect(executable_subject.to_s).to match(%r(OBJECTS\s+=\s+\$\(OBJECT_DIR\)/one\.o \$\(OBJECT_DIR\)/two\.o))
      end
    end

    context 'actions' do
      context 'for executable' do
        it 'builds the target' do
          expected = <<EOT
$(EXECUTABLE_TARGET): $(OBJECTS)
	$(LINKER) $(LINK_FLAGS) -o $(EXECUTABLE_TARGET) $(OBJECTS)
EOT
          expect(executable_subject.to_s).to include(expected)
        end
      end

      context 'for static library' do
        it 'builds the target' do
          expected = <<EOT
$(LIB_TARGET): $(OBJECTS)
	rm -f $(LIB_TARGET)
	ar -cq $(LIB_TARGET) $(OBJECTS)
	ranlib $(LIB_TARGET)
EOT
          expect(static_library_subject.to_s).to include(expected)
        end
      end

      context 'for shared library' do
        it 'builds the target' do
          expected = <<EOT
$(LIB_TARGET): $(OBJECTS)
	$(LINKER) -shared -o $(LIB_TARGET) $(OBJECTS) $(LINK_FLAGS)
EOT
          expect(shared_library_subject.to_s).to include(expected)
        end
      end
    end
  end

  context '#save' do
    it 'creates the makefile' do
      File.should_receive(:open).with(makefile_name, 'w')

      executable_subject.save
    end

    it 'saves' do
      file = stub('File')
      File.stub(:open).with(makefile_name, 'w') do |&block|
        block.call file
      end

      file.should_receive(:write).with(/COMPILER.*?= the_compiler/)

      executable_subject.save
    end
  end
end

