require 'rubygems' if RUBY_VERSION < '1.9'
require 'rake'
require 'rake/gempackagetask'
require 'spec/rake/spectask'
require 'rake/rdoctask'
$:.unshift(File.dirname(__FILE__) + '/lib')
require 'rake/cpp'

RDOC_OPTS = ['--quiet', '--main', 'README.rdoc', '--inline-source']

spec = Gem::Specification.new do |s|
  s.name             = 'rake-cpp'
  s.summary          = 'Rake for C/C++ Projects'
  s.description      = 'Provides Rake:CPP, a specific rake TaskLib for building C and C++ projects'
  s.version          = Rake::Cpp::VERSION::STRING

  s.homepage         = 'http://github.com/joeyates/rake-cpp'
  s.author           = 'Joe Yates'
  s.email            = 'joe.g.yates@gmail.com'

  s.files            = ['README.rdoc', 'COPYING', 'Rakefile'] + FileList['{lib,test}/**/*.rb']
  s.require_paths    = ['lib']
  s.add_dependency('rake', '>= 0.8.7')

  s.has_rdoc         = true
  s.rdoc_options     += RDOC_OPTS
  s.extra_rdoc_files = ['README.rdoc', 'COPYING']

  s.test_file = 'test/all_tests.rb'
end

Rake::GemPackageTask.new(spec) do |pkg|
end

Spec::Rake::SpecTask.new do |t|
  t.spec_files       = FileList['spec/**/*_spec.rb']
  t.spec_opts        += [ '--color', '--format specdoc' ]
end

Spec::Rake::SpecTask.new('spec:rcov') do |t|
  t.spec_files       = FileList['spec/**/*_spec.rb']
  t.rcov             = true
  t.rcov_opts        = [ '--exclude spec' ]
end

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir      = 'html'
  rdoc.options       += RDOC_OPTS
  rdoc.title         = 'Rake for C/C++ Projects'
  rdoc.rdoc_files.add ['README.rdoc', 'COPYING', 'lib/**/*.rb']
end
