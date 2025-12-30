# Collator

Locale-aware string comparison. Equivalent to JavaScript's Intl.Collator.

---

## Class Structure

```
ICU4X
└─ Collator
```

---

## ICU4X::Collator

A class for comparing strings according to locale-specific rules.

### Interface

```ruby
module ICU4X
  class Collator
    # Constructor
    # @param locale [Locale] Locale
    # @param provider [DataProvider] Data provider
    # @param sensitivity [Symbol] :base, :accent, :case, or :variant (default)
    # @param numeric [Boolean] Enable numeric sorting (default: false)
    # @param case_first [Symbol] :upper, :lower, or nil (default)
    # @raise [ArgumentError] If sensitivity or case_first is invalid
    # @raise [TypeError] If provider is not a DataProvider
    # @raise [Error] If data loading fails
    def initialize(locale, provider:, sensitivity: :variant, numeric: false, case_first: nil) = ...

    # Compare two strings
    # @param a [String] First string
    # @param b [String] Second string
    # @return [Integer] -1 if a < b, 0 if a == b, 1 if a > b
    # @raise [TypeError] If arguments are not Strings
    def compare(a, b) = ...

    # Get resolved options
    # @return [Hash]
    def resolved_options = ...
  end
end
```

---

## sensitivity Option

| Value | Description | "a" vs "A" | "a" vs "á" |
|-------|-------------|------------|------------|
| `:base` | Base letters only | equal | equal |
| `:accent` | Base + accents | equal | different |
| `:case` | Base + case | different | equal |
| `:variant` | All differences (default) | different | different |

---

## numeric Option

| Value | "file2" vs "file10" |
|-------|---------------------|
| `false` (default) | "file2" > "file10" (lexicographic) |
| `true` | "file2" < "file10" (numeric) |

---

## case_first Option

| Value | Description |
|-------|-------------|
| `nil` (default) | Locale default |
| `:upper` | Uppercase first |
| `:lower` | Lowercase first |

---

## Usage Examples

### Basic Comparison

```ruby
provider = ICU4X::DataProvider.from_blob(Pathname.new("data/i18n.blob"))
locale = ICU4X::Locale.parse("en")

collator = ICU4X::Collator.new(locale, provider: provider)

collator.compare("apple", "banana")  # => -1
collator.compare("apple", "apple")   # => 0
collator.compare("banana", "apple")  # => 1
```

### Case-Insensitive Comparison

```ruby
collator = ICU4X::Collator.new(locale, provider: provider, sensitivity: :base)

collator.compare("a", "A")  # => 0
collator.compare("a", "á")  # => 0
```

### Numeric Sorting

```ruby
# Without numeric option (lexicographic)
collator = ICU4X::Collator.new(locale, provider: provider)
collator.compare("file2", "file10")  # => 1 (because "2" > "1")

# With numeric option
collator = ICU4X::Collator.new(locale, provider: provider, numeric: true)
collator.compare("file2", "file10")  # => -1 (because 2 < 10)
```

### Sorting Arrays

```ruby
collator = ICU4X::Collator.new(locale, provider: provider)

names = ["Zoe", "André", "alice", "Bob"]
sorted = names.sort { |a, b| collator.compare(a, b) }
# => ["alice", "André", "Bob", "Zoe"]

# Case-insensitive sorting
collator_base = ICU4X::Collator.new(locale, provider: provider, sensitivity: :base)
sorted = names.sort { |a, b| collator_base.compare(a, b) }
# => ["alice", "André", "Bob", "Zoe"]
```

### German Locale

```ruby
locale_de = ICU4X::Locale.parse("de")
collator = ICU4X::Collator.new(locale_de, provider: provider)

# German ä is treated as a variant of a
collator.compare("ä", "b")  # => -1
```

### Japanese Locale

```ruby
locale_ja = ICU4X::Locale.parse("ja")
collator = ICU4X::Collator.new(locale_ja, provider: provider)

# Hiragana ordering
collator.compare("あ", "い")  # => -1
collator.compare("い", "う")  # => -1
```

---

## Notes

- The `compare` method returns standard comparison values: -1, 0, or 1
- Use with `Array#sort` by passing a block: `array.sort { |a, b| collator.compare(a, b) }`
- Collation rules vary significantly by locale
- The `:case` sensitivity uses case level to detect case while ignoring accents
