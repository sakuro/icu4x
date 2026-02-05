# frozen_string_literal: true

require "dry-configurable"
require "pathname"

# Native extension - try version-specific path for precompiled gems first
begin
  RUBY_VERSION =~ /\A(\d+\.\d+)/
  require_relative "icu4x/#{$1}/icu4x"
rescue LoadError
  require_relative "icu4x/icu4x"
end
require_relative "icu4x/version"

# ICU4X provides Ruby bindings for ICU4X, a Unicode library.
#
# This module serves as the namespace for the gem's functionality.
module ICU4X
  extend Dry::Configurable

  setting :data_path, default: nil, constructor: ->(v) { v.nil? ? nil : Pathname(v) }

  @default_provider_mutex = Mutex.new

  # Returns the default provider, lazily loaded from configuration or environment.
  # @return [DataProvider, nil] The default provider, or nil if not configured
  def self.default_provider
    @default_provider_mutex.synchronize do
      @default_provider ||= begin
        path = config.data_path || ENV["ICU4X_DATA_PATH"]&.then {|p| Pathname(p) }
        path && DataProvider.from_blob(path)
      end
    end
  end

  # Resets the cached default provider. Useful for testing.
  # @return [void]
  def self.reset_default_provider!
    @default_provider_mutex.synchronize do
      @default_provider = nil
    end
  end

  # Base error class for all ICU4X errors
  class Error < StandardError; end

  # Error raised when locale parsing fails
  class LocaleError < Error; end

  # Error raised when data loading fails
  class DataError < Error; end

  # Error raised when data generation fails
  class DataGeneratorError < Error; end

  FormattedPart = Data.define(:type, :value)

  # Represents a part of a formatted string.
  #
  # Used by format_to_parts methods in DateTimeFormat, NumberFormat,
  # ListFormat, and RelativeTimeFormat.
  #
  # @!attribute [r] type
  #   @return [Symbol] The part type (e.g., :integer, :literal, :year)
  # @!attribute [r] value
  #   @return [String] The formatted value
  class FormattedPart
    # @return [String] Human-readable representation
    def inspect = "#<ICU4X::FormattedPart type=#{type.inspect} value=#{value.inspect}>"
  end

  class Segmenter
    Segment = Data.define(:segment, :index, :word_like)

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
