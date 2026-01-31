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
    # Parse a BCP 47 locale string
    # @param locale_str [String] Locale string in BCP 47 format
    # @return [Locale]
    # @raise [LocaleError] If the format is invalid
    def self.parse_bcp47(locale_str) = ...

    # Alias for parse_bcp47
    alias parse parse_bcp47

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

    # Maximize locale in place (Add Likely Subtags algorithm, UTS #35)
    # @return [self, nil] self if modified, nil if unchanged
    def maximize! = ...

    # Return a new maximized locale
    # @return [Locale] new locale with likely subtags added
    def maximize = ...

    # Minimize locale in place (Remove Likely Subtags algorithm, UTS #35)
    # @return [self, nil] self if modified, nil if unchanged
    def minimize! = ...

    # Return a new minimized locale
    # @return [Locale] new locale with redundant subtags removed
    def minimize = ...
  end
end
```

### Usage Examples

```ruby
# Parse BCP 47 format (parse_bcp47 or its alias parse)
loc = ICU4X::Locale.parse_bcp47("ja-JP")
# or
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

# Maximize: add likely subtags
loc6 = ICU4X::Locale.parse("en")
loc6.maximize!     # => loc6 (self)
loc6.to_s          # => "en-Latn-US"

# Non-destructive maximize
loc7 = ICU4X::Locale.parse("zh")
expanded = loc7.maximize
loc7.to_s          # => "zh" (unchanged)
expanded.to_s      # => "zh-Hans-CN"

# Minimize: remove redundant subtags
loc8 = ICU4X::Locale.parse("ja-Jpan-JP")
loc8.minimize!     # => loc8 (self)
loc8.to_s          # => "ja"

# Non-destructive minimize
loc9 = ICU4X::Locale.parse("en-Latn-US")
minimal = loc9.minimize
loc9.to_s          # => "en-Latn-US" (unchanged)
minimal.to_s       # => "en"
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
