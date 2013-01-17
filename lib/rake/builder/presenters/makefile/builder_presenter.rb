module Rake::Builder::Presenters; end

module Rake::Builder::Presenters::Makefile
  class BuilderPresenter
    def initialize(builder)
      @builder = builder
    end

    def to_s
      objects      = @builder.object_files.collect { |f| f.sub(@builder.objects_path, '$(OBJECT_DIR)') }
      objects_list = objects.join( ' ' )
      case @builder.target_type
      when :executable
        target_name = 'EXECUTABLE_TARGET'
        target_ref  = "$(#{target_name})"
        target_actions =
"	$(LINKER) $(LINK_FLAGS) -o #{target_ref} $(OBJECTS)
"
      when :static_library
        target_name = 'LIB_TARGET'
        target_ref  = "$(#{target_name})"
        target_actions =
"	rm -f #{target_ref}
	ar -cq #{target_ref} $(OBJECTS)
	ranlib #{target_ref}
"
      when :shared_library
        target_name = 'LIB_TARGET'
        target_ref  = "$(#{target_name})"
        target_actions =
"	$(LINKER) -shared -o #{target_ref} $(OBJECTS) $(LINK_FLAGS)
"
      end

      variables = <<EOT
COMPILER       = #{@builder.compiler}
COMPILER_FLAGS = #{@builder.compiler_flags}
LINKER         = #{@builder.linker}
LINK_FLAGS     = #{@builder.link_flags}
OBJECT_DIR     = #{@builder.objects_path}
OBJECTS        = #{objects_list}
#{ target_name } = #{@builder.target}
EOT
      rules = <<EOT

all: #{target_ref}

clean:
	rm -f $(OBJECTS)
	rm -f #{target_ref}

#{target_ref}: $(OBJECTS)
#{target_actions}
EOT

      source_groups = group_files_by_path(@builder.source_files)
      source_groups.each.with_index do | gp, i |
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
  end
end

