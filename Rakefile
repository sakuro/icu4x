# frozen_string_literal: true

require "bundler/gem_tasks"

require "rake/clean"
CLEAN.include("coverage", ".rspec_status", ".yardoc")
CLOBBER.include("doc/api", "pkg", "lib/**/*.bundle", "lib/**/*.so", "lib/**/*.dll", "spec/fixtures/*.postcard")

require "rb_sys/extensiontask"
RbSys::ExtensionTask.new("icu4x") do |ext|
  ext.lib_dir = "lib/icu4x"
  ext.cross_compile = true
  ext.cross_platform = %w[
    x86_64-linux
    aarch64-linux
    x86_64-darwin
    arm64-darwin
    x64-mingw-ucrt
  ]
end

require "rubocop/rake_task"
RuboCop::RakeTask.new

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

TEST_BLOB = "spec/fixtures/test-data.postcard"
TEST_BLOB_LOCALES = %w[en ja ru ar de und].freeze

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
