# frozen_string_literal: true

require "zeitwerk"
require_relative "icu4x/version"

# Icu4x provides [description of your gem].
#
# This module serves as the namespace for the gem's functionality.
module Icu4x
  class Error < StandardError; end

  loader = Zeitwerk::Loader.for_gem
  loader.ignore("#{__dir__}/icu4x/version.rb")
  # loader.inflector.inflect(
  #   "html" => "HTML",
  #   "ssl" => "SSL"
  # )
  loader.setup
end
