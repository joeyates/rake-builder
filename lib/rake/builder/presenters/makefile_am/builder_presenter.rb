module Rake::Builder::Presenters::MakefileAm
  class BuilderPresenter
    attr_accessor :builder

    def initialize(builder)
      @builder = builder
    end

    def to_s
      [sources, cpp_flags, ld_flags, libraries, ''].compact.join("\n")
    end

    private

    def sources
      "#{builder.label}_SOURCES = #{builder.source_files.join(' ')}"
    end

    def cpp_flags
      "#{builder.label}_CPPFLAGS = #{builder.compiler_flags}"
    end

    def ld_flags
      if builder.is_library?
        nil
      else
        "#{builder.label}_LDFLAGS  = -L."
      end
    end

    def libraries
      if builder.is_library?
        nil
      else
        "#{builder.label}_LDADD  = #{builder.library_dependencies_list}"
      end
    end
  end
end

