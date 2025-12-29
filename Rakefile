# frozen_string_literal: true

require "bundler/gem_tasks"

require "rake/clean"
CLEAN.include("coverage", ".rspec_status", ".yardoc")
CLOBBER.include("doc/api", "pkg", "lib/**/*.bundle", "lib/**/*.so", "lib/**/*.dll")

require "rb_sys/extensiontask"
RbSys::ExtensionTask.new("icu4x") do |ext|
  ext.lib_dir = "lib/icu4x"
end

require "rubocop/rake_task"
RuboCop::RakeTask.new

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)
Rake::Task[:spec].enhance([:compile])

require "yard"
YARD::Rake::YardocTask.new(:doc)

task default: %i[spec rubocop]
