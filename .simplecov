# frozen_string_literal: true

SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"
  add_filter "/examples/"

  minimum_coverage 80.0
  # minimum_coverage_by_file 70

  enable_coverage :branch

  # Coverage formats
  formatter SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter, # HTML report in coverage/
      SimpleCov::Formatter::SimpleFormatter # Console output
    ]
  )

  # Merge multiple test runs (useful for parallel testing)
  merge_timeout 3600
end
