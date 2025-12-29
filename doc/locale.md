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
loc = ICU4X::Locale.parse("ja-JP")
loc.language  # => "ja"
loc.region    # => "JP"
loc.script    # => nil
loc.to_s      # => "ja-JP"

loc2 = ICU4X::Locale.parse("en-Latn-US")
loc2.script   # => "Latn"

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
