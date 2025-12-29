# Locale

Locale handling for ICU4X.

---

## Class Structure

```
ICU4X
├─ Locale
└─ Error
   ├─ LocaleError
   ├─ DataError
   └─ DataGeneratorError
```

---

## ICU4X::Locale

A class representing locale identifiers. Supports BCP 47 format.

### Interface

```ruby
module ICU4X
  class Locale
    # Parse a locale string
    # @param locale_str [String] Locale string in BCP 47 format
    # @return [Locale]
    # @raise [LocaleError] If the format is invalid
    def self.parse(locale_str) = ...

    # Parse a POSIX locale string
    # @param posix_str [String] Locale string in POSIX format (e.g., "ja_JP.UTF-8")
    # @return [Locale]
    # @raise [LocaleError] If the format is invalid
    def self.parse_posix(posix_str) = ...

    # Language code
    # @return [String, nil]
    def language = ...

    # Script code
    # @return [String, nil]
    def script = ...

    # Region code
    # @return [String, nil]
    def region = ...

    # Locale extensions
    # @return [Hash] { unicode: Hash, transform: String?, private: Array }
    def extensions = ...

    # String representation
    # @return [String]
    def to_s = ...

    # Equality check
    # @param other [Locale]
    # @return [Boolean]
    def ==(other) = ...

    # Hash equality
    # @param other [Locale]
    # @return [Boolean]
    def eql?(other) = ...

    # Hash code
    # @return [Integer]
    def hash = ...
  end
end
```

### Usage Examples

```ruby
# Parse BCP 47 format
loc = ICU4X::Locale.parse("ja-JP")
loc.language  # => "ja"
loc.region    # => "JP"
loc.script    # => nil
loc.to_s      # => "ja-JP"

loc2 = ICU4X::Locale.parse("en-Latn-US")
loc2.script   # => "Latn"

# Parse POSIX format
loc3 = ICU4X::Locale.parse_posix("ja_JP.UTF-8")
loc3.language  # => "ja"
loc3.region    # => "JP"
loc3.to_s      # => "ja-JP"

# POSIX modifiers @latin/@cyrillic are converted to script codes
loc4 = ICU4X::Locale.parse_posix("sr_RS@latin")
loc4.script    # => "Latn"

# C and POSIX locales become undetermined (und)
loc5 = ICU4X::Locale.parse_posix("C")
loc5.to_s      # => "und"

# Locales can be used as Hash keys
cache = {}
cache[loc] = "cached value"
```

---

## Error Classes

```ruby
module ICU4X
  # Base error class
  class Error < StandardError; end

  # Raised when locale parsing fails
  class LocaleError < Error; end

  # Raised when data loading fails
  class DataError < Error; end

  # Raised when data generation fails
  class DataGeneratorError < Error; end
end
```
