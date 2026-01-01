# frozen_string_literal: true

require "bundler/gem_tasks"

require "rake/clean"
CLEAN.include("coverage", ".rspec_status", ".yardoc")
CLOBBER.include("doc/api", "pkg", "lib/**/*.bundle", "lib/**/*.so", "lib/**/*.dll", "spec/fixtures/*.postcard")

require "rb_sys/extensiontask"

gemspec = Gem::Specification.load("icu4x.gemspec")

RbSys::ExtensionTask.new("icu4x", gemspec) do |ext|
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

# Development tasks are not needed during cross-compilation (RUBY_TARGET is set by rb-sys-dock)
unless ENV["RUBY_TARGET"]
  require "rubocop/rake_task"
  RuboCop::RakeTask.new

  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)

  require "icu4x/rake_task"
  TEST_BLOB = "spec/fixtures/test-data.postcard"

  ICU4X::RakeTask.new do |t|
    t.locales = %w[en ja ru ar de]
    t.output = TEST_BLOB
  end

  Rake::Task[TEST_BLOB].enhance([:compile])
  Rake::Task[:spec].enhance([TEST_BLOB])

  require "yard"
  YARD::Rake::YardocTask.new(:doc)

  task default: %i[spec rubocop]
end
