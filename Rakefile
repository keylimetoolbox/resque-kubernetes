# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "bundler/audit/task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new
Bundler::Audit::Task.new

# Remove default and replace with a series of test tasks
task default: []
Rake::Task[:default].clear

task default: %w[spec rubocop bundle:audit]
