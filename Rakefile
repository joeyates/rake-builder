require 'rubygems' if RUBY_VERSION < '1.9'
require 'rake'
require 'rake/rdoctask'
require 'spec/rake/spectask'
$:.unshift( File.dirname( __FILE__ ) + '/lib' )
require 'rake/builder/version'

RDOC_FILES           = FileList[ 'COPYING', 'README.rdoc' ] +
                       FileList[ 'lib/**/*.rb' ] +
                       FileList[ 'examples/README.rdoc' ] +
                       FileList[ 'examples/**/Rakefile' ]
RDOC_OPTS            = [ '--quiet', '--main', 'README.rdoc', '--inline-source' ]

Spec::Rake::SpecTask.new do |t|
  t.spec_files       = FileList[ 'spec/**/*_spec.rb' ]
  t.spec_opts        += [ '--color', '--format specdoc' ]
end

Spec::Rake::SpecTask.new( 'spec:rcov' ) do |t|
  t.spec_files       = FileList[ 'spec/**/*_spec.rb' ]
  t.rcov             = true
  t.rcov_opts        = [ '--exclude spec' ]
end

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir      = 'html'
  rdoc.options       += RDOC_OPTS
  rdoc.title         = 'Rake for C/C++/Objective-C/Objective-C++ Projects'
  rdoc.rdoc_files.add RDOC_FILES
end

desc "Build the gem"
task :build do
  system "gem build rake-builder.gemspec"
end

desc "Publish gem version #{ Rake::Builder::VERSION::STRING }"
task :release => :build do
  system "gem push rake-builder-#{ Rake::Builder::VERSION::STRING }.gem"
end
