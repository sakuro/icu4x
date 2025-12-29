# frozen_string_literal: true

require "bundler/gem_tasks"

require "rake/clean"
CLEAN.include("coverage", ".rspec_status", ".yardoc")
CLOBBER.include("doc/api", "pkg")

require "rubocop/rake_task"
RuboCop::RakeTask.new

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

require "yard"
YARD::Rake::YardocTask.new(:doc)

task default: %i[spec rubocop]
