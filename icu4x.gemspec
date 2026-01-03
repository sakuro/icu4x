# frozen_string_literal: true

require_relative "lib/icu4x/version"

Gem::Specification.new do |spec|
  spec.name = "icu4x"
  spec.version = ICU4X::VERSION
  spec.authors = ["OZAWA Sakuro"]
  spec.email = ["10973+sakuro@users.noreply.github.com"]

  spec.summary = "Ruby bindings for ICU4X Unicode internationalization library"
  spec.description = <<~DESC.chomp
    ICU4X provides Ruby bindings for the ICU4X library, offering Unicode
    internationalization support including locale handling, number formatting,
    date/time formatting, collation, segmentation, and more.
  DESC
  spec.homepage = "https://github.com/sakuro/icu4x"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}.git"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) {
    Dir[
      "lib/icu4x.rb",
      "lib/icu4x/**/*.rb",
      "Cargo.toml",
      "Cargo.lock",
      "ext/icu4x/extconf.rb",
      "ext/icu4x/Cargo.toml",
      "ext/icu4x/**/*.rs",
      "ext/icu4x_macros/Cargo.toml",
      "ext/icu4x_macros/**/*.rs",
      "sig/icu4x.rbs",
      "LICENSE.txt",
      "README.md",
      "CHANGELOG.md"
    ]
  }
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/icu4x/extconf.rb"]

  spec.add_dependency "dry-configurable", "~> 1.3"
  spec.add_dependency "rb_sys", "~> 0.9"
end
