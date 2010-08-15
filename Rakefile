require 'rubygems' if RUBY_VERSION < '1.9'
require 'rake'
require 'rake/gempackagetask'
require 'spec/rake/spectask'
require 'rake/rdoctask'
$:.unshift( File.dirname( __FILE__ ) + '/lib' )
require 'rake/cpp'

ADMIN_FILES          = FileList[ 'CHANGES', 'COPYING', 'Rakefile', 'README.rdoc' ]
SOURCE_FILES         = FileList[ 'lib/**/*.rb' ]
SPEC_FILES           = FileList[ 'spec/**/*' ]
EXAMPLE_EXTRA_FILES  = FileList[ 'examples/README.rdoc' ] + FileList[ 'examples/**/Rakefile' ]
EXAMPLE_SOURCE_FILES = FileList[ 'examples/**/*.{h,c,cpp}' ]
RDOC_FILES           = FileList[ 'COPYING', 'README.rdoc' ] + SOURCE_FILES + EXAMPLE_EXTRA_FILES
RDOC_OPTS            = [ '--quiet', '--main', 'README.rdoc', '--inline-source' ]

spec = Gem::Specification.new do |s|
  s.name             = 'rake-cpp'
  s.summary          = 'Rake for C/C++ Projects'
  s.description      = 'Provides Rake:CPP, a specific rake TaskLib for building C and C++ projects'
  s.version          = Rake::Cpp::VERSION::STRING

  s.homepage         = 'http://github.com/joeyates/rake-cpp'
  s.author           = 'Joe Yates'
  s.email            = 'joe.g.yates@gmail.com'

  s.files            = ADMIN_FILES +
                       SOURCE_FILES +
                       EXAMPLE_SOURCE_FILES +
                       EXAMPLE_EXTRA_FILES
  s.require_paths    = [ 'lib' ]
  s.add_dependency( 'rake', '>= 0.8.7' )

  s.has_rdoc         = true
  s.rdoc_options     += RDOC_OPTS
  s.extra_rdoc_files = RDOC_FILES

  s.test_files       = SPEC_FILES
end

Rake::GemPackageTask.new( spec ) do |pkg|
end

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
  rdoc.title         = 'Rake for C/C++ Projects'
  rdoc.rdoc_files.add RDOC_FILES
end
