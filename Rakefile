# frozen_string_literal: true

require "bundler/gem_tasks"

require "rake/clean"
CLEAN.include("coverage", ".rspec_status", ".yardoc")
CLOBBER.include("doc/api", "pkg", "lib/**/*.bundle", "lib/**/*.so", "lib/**/*.dll", "spec/fixtures/*.postcard")

require "rb_sys/extensiontask"
RbSys::ExtensionTask.new("icu4x") do |ext|
  ext.lib_dir = "lib/icu4x"
end

require "rubocop/rake_task"
RuboCop::RakeTask.new

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

TEST_BLOB = "spec/fixtures/test-data.postcard"
TEST_BLOB_LOCALES = %w[en ja ru ar und].freeze

directory "spec/fixtures"

file TEST_BLOB => ["spec/fixtures", :compile] do |t|
  require "icu4x"
  require "pathname"
  ICU4X::DataGenerator.export(
    locales: TEST_BLOB_LOCALES,
    markers: :all,
    format: :blob,
    output: Pathname.new(t.name)
  )
end

Rake::Task[:spec].enhance([TEST_BLOB])

require "yard"
YARD::Rake::YardocTask.new(:doc)

task default: %i[spec rubocop]
