# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
  gem "rake", require: false

  gem "irb", require: false
  gem "repl_type_completor", require: false
end

group :development do
  # Ruby Language Server
  gem "ruby-lsp", require: false

  # Type checking
  gem "rbs", require: false
  gem "steep", require: false

  # RuboCop
  gem "docquet", require: false # An opionated RuboCop config tool
  gem "rubocop", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rake", require: false
  gem "rubocop-rspec", require: false

  # YARD
  gem "redcarpet", require: false
  gem "yard", github: "lsegal/yard", require: false # Version with Data.define support
end

group :test do
  # RSpec & SimpleCov
  gem "rspec", require: false
  gem "simplecov", require: false
end
