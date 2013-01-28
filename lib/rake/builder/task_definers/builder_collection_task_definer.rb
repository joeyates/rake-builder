class Rake::Builder::BuilderCollectionTaskDefiner
  def run
    desc "Create input files for configure script creation"
    task :autoconf, [:project_title, :version] => [] do |task, args|
      raise 'No Rake::Builder projects have been defined' unless Rake::Builder.instances.size > 0
      first = Rake::Builder.instances[0]
      Rake::Builder.create_autoconf(args.project_title, args.version, first.source_files[0])
    end
  end
end

