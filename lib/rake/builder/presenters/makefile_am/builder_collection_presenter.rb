module Rake; class Builder; module Presenters; module MakefileAm
  class BuilderCollectionPresenter
    attr_accessor :builders

    def initialize(builders)
      @builders = builders
    end

    def to_s
      programs_list + program_sections + libraries_list + library_sections
    end

    def save
      File.open('Makefile.am', 'w') do |f|
        f.write to_s
      end
    end

    private

    def programs
      @builders.reject(&:is_library?)
    end

    def libraries
      @builders.select(&:is_library?)
    end

    def programs_list
      'bin_PROGRAMS = ' + programs.map(&:label).join(' ') + "\n\n"
    end

    def libraries_list
      'lib_LIBRARIES = ' + libraries.map(&:label).join(' ') + "\n\n"
    end

    def program_sections
      programs.map do |program|
        presenter = Rake::Builder::Presenters::MakefileAm::BuilderPresenter.new(program)
        presenter.to_s
      end.join("\n")
    end

    def library_sections
      libraries.map do |lib|
        presenter = Rake::Builder::Presenters::MakefileAm::BuilderPresenter.new(lib)
        presenter.to_s
      end.join("\n")
    end
  end
end; end; end; end

