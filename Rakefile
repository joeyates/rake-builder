require "bundler/gem_tasks"
require 'rcov/rcovtask' if RUBY_VERSION < '1.9'
require 'rspec/core/rake_task'

task :default => :spec

RSpec::Core::RakeTask.new do | t |
  t.pattern = 'spec/**/*_spec.rb'
end

if RUBY_VERSION < '1.9'

  RSpec::Core::RakeTask.new( 'spec:rcov' ) do |t|
    t.pattern   = 'spec/**/*_spec.rb'
    t.rcov      = true
    t.rcov_opts = [ '--exclude', 'spec/,/gems/' ]
  end

end

