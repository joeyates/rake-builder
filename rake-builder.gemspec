require 'rake'
$:.unshift( File.dirname( __FILE__ ) + '/lib' )
require 'rake/builder/version'

ADMIN_FILES   = FileList[ 'CHANGES', 'COPYING', 'Rakefile', 'README.rdoc' ]
SOURCE_FILES  = FileList[ 'lib/**/*.rb' ]
EXAMPLE_FILES = FileList[ 'examples/**/*.{h,c,cpp,m}' ] +
                FileList[ 'examples/README.rdoc' ] +
                FileList[ 'examples/**/Rakefile' ]
SPEC_FILES    = FileList[ 'spec/**/*' ]

spec = Gem::Specification.new do |s|
  s.name              = 'rake-builder'
  s.summary           = 'Rake for C/C++ Projects'
  s.description       = 'Provides Rake:Builder, a specific rake TaskLib for building C, C++, Objective-C and Objective-C++ projects'
  s.version           = Rake::Builder::VERSION::STRING

  s.homepage          = 'http://github.com/joeyates/rake-builder'
  s.author            = 'Joe Yates'
  s.email             = 'joe.g.yates@gmail.com'
  s.rubyforge_project = 'nowarning'

  s.files            = ADMIN_FILES +
                       SOURCE_FILES +
                       EXAMPLE_FILES
  s.require_paths    = [ 'lib' ]

  s.test_files       = SPEC_FILES
end
