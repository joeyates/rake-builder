require 'rake'
$:.unshift( File.dirname( __FILE__ ) + '/lib' )
require 'rake/builder/version'

spec = Gem::Specification.new do |s|
  s.name              = 'rake-builder'
  s.summary           = 'Rake for C/C++ Projects'
  s.description       = 'Provides Rake:Builder, a specific rake TaskLib for building C, C++, Objective-C and Objective-C++ projects'
  s.version           = Rake::Builder::VERSION::STRING

  s.homepage          = 'http://github.com/joeyates/rake-builder'
  s.author            = 'Joe Yates'
  s.email             = 'joe.g.yates@gmail.com'
  s.rubyforge_project = 'nowarning'

  admin_files         = FileList[ 'CHANGES', 'COPYING', 'Rakefile', 'README.rdoc' ]
  source_files        = FileList[ 'lib/**/*.rb' ]
  example_files       = FileList[ 'examples/**/*.{h,c,cpp,m}' ] +
                        FileList[ 'examples/README.rdoc' ] +
                        FileList[ 'examples/**/Rakefile' ]
  spec_files          = FileList[ 'spec/**/*' ]
  s.files             = admin_files +
                        source_files +
                        example_files
  s.require_paths    = [ 'lib' ]

  s.test_files       = spec_files
end

