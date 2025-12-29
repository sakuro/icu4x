# frozen_string_literal: true

require_relative "icu4x/icu4x" # Native extension
require_relative "icu4x/version"

# ICU4X provides Ruby bindings for ICU4X, a Unicode library.
#
# This module serves as the namespace for the gem's functionality.
module ICU4X
  # Base error class for all ICU4X errors
  class Error < StandardError; end

  # Error raised when locale parsing fails
  class LocaleError < Error; end

  # Error raised when data loading fails
  class DataError < Error; end

  # Error raised when data generation fails
  class DataGeneratorError < Error; end
end

# Enhance the native Locale class
module ICU4X
  # Represents a BCP 47 locale identifier.
  class Locale
    # @return [String] Human-readable representation
    def inspect = "#<ICU4X::Locale:#{self}>"

    # @return [Integer] Hash code for use as Hash key
    def hash = to_s.hash

    # @param other [Locale] Another locale to compare
    # @return [Boolean] True if locales are equal
    def eql?(other) = self == other
  end
end
