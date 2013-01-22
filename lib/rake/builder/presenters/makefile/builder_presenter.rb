module Rake::Builder::Presenters; end

module Rake::Builder::Presenters::Makefile
  class BuilderPresenter
    def initialize(builder)
      @builder = builder
      check_target_type
    end

    def to_s
      check_target_type

      variables = main_variables
      rules     = main_rules

      source_groups = group_files_by_path(@builder.source_files)
      source_groups.each.with_index do |gp, i|
        variables << "SOURCE_#{i + 1} = #{gp[0]}\n"
        rules     << <<EOT

$(OBJECT_DIR)/%.o: $(SOURCE_#{i + 1})/%.cpp
	$(COMPILER) -c $(COMPILER_FLAGS) -o $@ $<
EOT
      end
      variables + rules
    end

    def save
      File.open(@builder.makefile_name, 'w') do |file|
        file.write to_s
      end
    end

    private

    def target_type
      @builder.target_type
    end

    def target_name
      case target_type
      when :executable
        'EXECUTABLE_TARGET'
      when :static_library
        'LIB_TARGET'
      when :shared_library
        'LIB_TARGET'
      end
    end

    def target_ref
      "$(#{target_name})"
    end

    def target_actions
      case target_type
      when :executable
"	$(LINKER) $(LINK_FLAGS) -o #{target_ref} $(OBJECTS)
"
      when :static_library
"	rm -f #{target_ref}
	ar -cq #{target_ref} $(OBJECTS)
	ranlib #{target_ref}
"
      when :shared_library
"	$(LINKER) -shared -o #{target_ref} $(OBJECTS) $(LINK_FLAGS)
"
      end
    end

    def main_variables
      <<EOT
COMPILER       = #{@builder.compiler}
COMPILER_FLAGS = #{@builder.compiler_flags}
LINKER         = #{@builder.linker}
LINK_FLAGS     = #{@builder.link_flags}
OBJECT_DIR     = #{@builder.objects_path}
OBJECTS        = #{objects_list}
#{target_name} = #{@builder.target}
EOT
    end

    def main_rules
      <<EOT

all: #{target_ref}

clean:
	rm -f $(OBJECTS)
	rm -f #{target_ref}

#{target_ref}: $(OBJECTS)
#{target_actions}
EOT
    end

    def objects_list
      objects = @builder.object_files.map { |f| f.sub(@builder.objects_path, '$(OBJECT_DIR)') }
      objects.join(' ')
    end

    def group_files_by_path(files)
      files.group_by do |f|
        m = f.match(/(.*?)?\/?([^\/]+)$/)
        m[1]
      end
    end

    def check_target_type
      return if [:executable, :shared_library, :static_library].include?(target_type)
      raise "Unknown build target type '#{target_type}'"
    end
  end
end

