# ListFormat

Locale-aware list formatting. Equivalent to JavaScript's Intl.ListFormat.

---

## Class Structure

```
ICU4X
└─ ListFormat
```

---

## ICU4X::ListFormat

A class for formatting lists of strings according to locale conventions.

### Interface

```ruby
module ICU4X
  class ListFormat
    # Constructor
    # @param locale [Locale] Locale
    # @param provider [DataProvider] Data provider
    # @param type [Symbol] :conjunction (default), :disjunction, or :unit
    # @param style [Symbol] :long (default), :short, or :narrow
    # @raise [ArgumentError] If type or style is invalid
    # @raise [Error] If data loading fails
    def initialize(locale, provider:, type: :conjunction, style: :long) = ...

    # Format a list
    # @param list [Array<String>] Array of strings to format
    # @return [String]
    # @raise [TypeError] If list is not an Array
    def format(list) = ...

    # Get resolved options
    # @return [Hash]
    def resolved_options = ...
  end
end
```

---

## type Option

| Value | Description | Example (en) |
|-------|-------------|--------------|
| `:conjunction` | "and" list (default) | "A, B, and C" |
| `:disjunction` | "or" list | "A, B, or C" |
| `:unit` | Unit list (no conjunction) | "A, B, C" |

---

## style Option

| Value | Description | Example (:conjunction, en) |
|-------|-------------|----------------------------|
| `:long` | Full format (default) | "A, B, and C" |
| `:short` | Shorter format | "A, B, & C" |
| `:narrow` | Minimal format | "A, B, C" |

---

## Usage Examples

### Basic List Formatting

```ruby
provider = ICU4X::DataProvider.from_blob(Pathname.new("data/i18n.blob"))
locale = ICU4X::Locale.parse("en-US")

lf = ICU4X::ListFormat.new(locale, provider: provider)

lf.format(["Apple", "Orange", "Banana"])
# => "Apple, Orange, and Banana"

lf.format(["Red", "Blue"])
# => "Red and Blue"

lf.format(["Single"])
# => "Single"
```

### Disjunction (Or)

```ruby
lf = ICU4X::ListFormat.new(locale, provider: provider, type: :disjunction)

lf.format(["Monday", "Tuesday", "Wednesday"])
# => "Monday, Tuesday, or Wednesday"
```

### Unit List

```ruby
lf = ICU4X::ListFormat.new(locale, provider: provider, type: :unit)

lf.format(["5 pounds", "3 ounces"])
# => "5 pounds, 3 ounces"
```

### Japanese Locale

```ruby
locale_ja = ICU4X::Locale.parse("ja")
lf = ICU4X::ListFormat.new(locale_ja, provider: provider)

lf.format(["りんご", "みかん", "バナナ"])
# => "りんご、みかん、バナナ"
```

### Style Variations

```ruby
# Short style
lf_short = ICU4X::ListFormat.new(locale, provider: provider, style: :short)
lf_short.format(["A", "B", "C"])
# => "A, B, & C"

# Narrow style
lf_narrow = ICU4X::ListFormat.new(locale, provider: provider, style: :narrow)
lf_narrow.format(["A", "B", "C"])
# => "A, B, C"
```

---

## Notes

- Empty arrays return an empty string
- Single-item arrays return the item as-is
- Two-item arrays use the appropriate conjunction without a comma
- List separator patterns vary by locale (e.g., Japanese uses "、" instead of ",")
