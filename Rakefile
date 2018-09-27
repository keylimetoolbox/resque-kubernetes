# frozen_string_literal: true

require "appraisal/task"
require "bundler/audit/task"
require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new
Bundler::Audit::Task.new
Appraisal::Task.new

# Remove default and replace with a series of test tasks
task default: []
Rake::Task[:default].clear

if ENV["APPRAISAL_INITIALIZED"]
  task default: %i[spec]
else
  task default: %i[rubocop bundle:audit appraisal]
end
