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

# Define Segment data class for Segmenter
module ICU4X
  class Segmenter
    Segment = Data.define(:segment, :index, :word_like)
  end
end

# Enhance the Segment data class
module ICU4X
  class Segmenter
    # Represents a segment of text.
    #
    # @!attribute [r] segment
    #   @return [String] The segment string
    # @!attribute [r] index
    #   @return [Integer] Byte offset in original text
    class Segment
      # Whether this segment is word-like.
      # @return [Boolean] true if word-like (letters, numbers, CJK ideographs)
      # @return [nil] for non-word granularity
      alias word_like? word_like
      private :word_like
    end
  end
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
