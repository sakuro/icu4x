# PluralRules

Plural rules functionality. Equivalent to JavaScript Intl.PluralRules.

**Status**: Future implementation

---

## Class Structure

```
ICU4X
└─ PluralRules
```

---

## ICU4X::PluralRules

A class for determining plural categories based on locale.

### Interface

```ruby
module ICU4X
  class PluralRules
    # Constructor
    # @param locale [Locale] Locale
    # @param provider [DataProvider] Data provider
    # @param type [Symbol] :cardinal (cardinal) or :ordinal (ordinal)
    # @raise [Error] If options are invalid
    def initialize(locale, provider:, type: :cardinal) = ...

    # Determine plural category
    # @param number [Numeric] Target to evaluate
    # @return [Symbol] :zero, :one, :two, :few, :many, :other
    def select(number) = ...

    # List of available categories
    # @return [Array<Symbol>]
    def categories = ...

    # Resolved options
    # @return [Hash]
    def resolved_options = ...
  end
end
```

---

## Plural Categories

Six categories defined by CLDR:

| Category | Description | English Example |
|----------|-------------|-----------------|
| `:zero` | Zero | (not used in English) |
| `:one` | Singular | 1 item |
| `:two` | Dual | (not used in English) |
| `:few` | Few | (not used in English) |
| `:many` | Many | (not used in English) |
| `:other` | Other | 0 items, 2 items, ... |

**Note**: Categories used vary by language.

### Examples by Language

| Language | Categories Used |
|----------|-----------------|
| English (en) | :one, :other |
| Japanese (ja) | :other only |
| Russian (ru) | :one, :few, :many, :other |
| Arabic (ar) | :zero, :one, :two, :few, :many, :other |

---

## type Option

### :cardinal (Cardinal)

Plural forms for quantities. Default.

```ruby
pr = ICU4X::PluralRules.new(
  ICU4X::Locale.parse("en"),
  provider: provider,
  type: :cardinal
)

pr.select(1)   # => :one   ("1 item")
pr.select(2)   # => :other ("2 items")
pr.select(0)   # => :other ("0 items")
```

### :ordinal (Ordinal)

Plural forms for ordering.

```ruby
pr = ICU4X::PluralRules.new(
  ICU4X::Locale.parse("en"),
  provider: provider,
  type: :ordinal
)

pr.select(1)   # => :one   ("1st")
pr.select(2)   # => :two   ("2nd")
pr.select(3)   # => :few   ("3rd")
pr.select(4)   # => :other ("4th")
pr.select(21)  # => :one   ("21st")
pr.select(22)  # => :two   ("22nd")
```

---

## Usage Examples

### Basic Usage

```ruby
provider = ICU4X::DataProvider.from_blob(Pathname.new("data/i18n.blob"))

# English
pr_en = ICU4X::PluralRules.new(
  ICU4X::Locale.parse("en"),
  provider: provider,
  type: :cardinal
)

pr_en.select(1)   # => :one
pr_en.select(5)   # => :other

# Japanese (always :other)
pr_ja = ICU4X::PluralRules.new(
  ICU4X::Locale.parse("ja"),
  provider: provider,
  type: :cardinal
)

pr_ja.select(1)   # => :other
pr_ja.select(5)   # => :other
```

### Getting Available Categories

```ruby
pr_en = ICU4X::PluralRules.new(
  ICU4X::Locale.parse("en"),
  provider: provider
)

pr_en.categories
# => [:one, :other]

pr_ru = ICU4X::PluralRules.new(
  ICU4X::Locale.parse("ru"),
  provider: provider
)

pr_ru.categories
# => [:one, :few, :many, :other]
```

### Example with I18n

```ruby
# Translation file
# en:
#   items:
#     one: "%{count} item"
#     other: "%{count} items"

def pluralize_items(count, locale:, provider:)
  pr = ICU4X::PluralRules.new(locale, provider: provider)
  category = pr.select(count)
  I18n.t("items.#{category}", count: count, locale: locale.to_s)
end

pluralize_items(1, locale: ICU4X::Locale.parse("en"), provider: provider)
# => "1 item"

pluralize_items(5, locale: ICU4X::Locale.parse("en"), provider: provider)
# => "5 items"
```

---

## Rust Extension

When implemented, will be added to `ext/icu4x/src/`.

### Dependent Crates

```toml
[dependencies]
icu_plurals = "2.0"
fixed_decimal = "0.5"
```

### Rust Module Structure

```
ext/icu4x/src/
├─ lib.rs           # Entry point (add plural_rules module)
└─ plural_rules.rs  # PluralRules bindings
```

---

## Test Data Generation

```bash
# Test data for plurals (includes ru, ar for full category coverage)
$ icu4x-datagen --locales en,ja,ru,ar --markers plurals --format blob --output spec/fixtures/test.blob
```

---

## Design Notes

- Supports decimals (e.g., 1.5 is :other in English)
- Category meanings differ by language
- Can be used in combination with Rails I18n pluralization

---

## Development/Test Locales

### Plural Category Coverage

Multiple locales are needed to test all 6 categories:

| Category | Example Test Locales |
|----------|---------------------|
| `:zero` | Arabic (ar) |
| `:one` | English (en), Russian (ru) |
| `:two` | Arabic (ar) |
| `:few` | Russian (ru), Arabic (ar) |
| `:many` | Russian (ru), Arabic (ar) |
| `:other` | All languages |

### Recommended Test Locale Set

**Minimum Set (3 locales)**:
- `en` - English: `:one`, `:other`
- `ru` - Russian: `:one`, `:few`, `:many`, `:other`
- `ar` - Arabic: All 6 categories

```ruby
TEST_LOCALES = %w[en ru ar].freeze
```

### Testing Ordinals

English ordinals have special patterns:

```ruby
# English ordinal test cases
{
  1 => :one,   # 1st
  2 => :two,   # 2nd
  3 => :few,   # 3rd
  4 => :other, # 4th
  11 => :other, # 11th (exception)
  12 => :other, # 12th (exception)
  13 => :other, # 13th (exception)
  21 => :one,  # 21st
  22 => :two,  # 22nd
  23 => :few,  # 23rd
}
```

### Test Data Generation with DataGenerator

```ruby
# Development/test data generation
ICU4X::DataGenerator.export(
  locales: %w[en ru ar ja],  # ja is :other only, but for Japanese environment testing
  markers: [:plurals],
  format: :blob,
  output: Pathname.new("spec/fixtures/plurals_test.blob")
)
```

---

## Related

- [icu4x.md](./icu4x.md)
- [data_provider.md](./data_provider.md)
- [icu4x_ruby_design.md](../icu4x_ruby_design.md) - Section 6
- [CLDR Plural Rules](https://cldr.unicode.org/index/cldr-spec/plural-rules)
