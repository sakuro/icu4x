# frozen_string_literal: true

require "simplecov"
SimpleCov.start

require "dry/configurable/test_interface"
require "icu4x"

ICU4X.enable_test_interface

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset ICU4X configuration between tests
  config.before do
    ICU4X.reset_config
    ICU4X.reset_default_provider!
  end
end
