require 'rake'
$:.unshift( File.dirname( __FILE__ ) + '/lib' )
require 'rake/builder'

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
  s.files             = admin_files +
                        source_files +
                        example_files
  s.require_paths    = [ 'lib' ]

  s.add_runtime_dependency     'rake',   '0.8.7'
  s.add_runtime_dependency     'json'

  s.add_development_dependency 'rspec',  '>= 2.3.0'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'pry-doc'

  s.test_files       = FileList[ 'spec/**/*' ]
end

