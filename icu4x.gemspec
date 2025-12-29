# frozen_string_literal: true

require_relative "lib/icu4x/version"

Gem::Specification.new do |spec|
  spec.name = "icu4x"
  spec.version = ICU4X::VERSION
  spec.authors = ["OZAWA Sakuro"]
  spec.email = ["10973+sakuro@users.noreply.github.com"]

  spec.summary = "icu4x"
  spec.description = "icu4x"
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
      "ext/icu4x/extconf.rb",
      "ext/icu4x/Cargo.toml",
      "ext/icu4x/**/*.rs",
      "sig/icu4x.rbs",
      "LICENSE.txt",
      "README.md",
      "CHANGELOG.md"
    ]
  }
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/icu4x/extconf.rb"]

  spec.add_dependency "rb_sys", "~> 0.9"
end
