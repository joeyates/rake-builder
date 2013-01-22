require "bundler/gem_tasks"
require 'rcov/rcovtask' if RUBY_VERSION < '1.9'
require 'rspec/core/rake_task'

task :default => :spec

RSpec::Core::RakeTask.new do |t|
  t.pattern = 'spec/**/*_spec.rb'
end

if RUBY_VERSION < '1.9'
  RSpec::Core::RakeTask.new('spec:rcov') do |t|
    t.pattern   = 'spec/**/*_spec.rb'
    t.rcov      = true
    t.rcov_opts = ['--exclude', 'spec/,/gems/']
  end
else
  desc 'Run specs and create coverage output'
  RSpec::Core::RakeTask.new('spec:coverage') do |t|
    t.pattern = ['spec/gather_rspec_coverage.rb', 'spec/**/*_spec.rb']
  end
end

