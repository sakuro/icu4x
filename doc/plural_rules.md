# PluralRules

Plural rules functionality. Equivalent to JavaScript's Intl.PluralRules.

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
    # @param number [Numeric] Number to evaluate
    # @return [Symbol] :zero, :one, :two, :few, :many, :other
    def select(number) = ...

    # Determine plural category for a range
    # @param start_value [Numeric] Start of the range
    # @param end_value [Numeric] End of the range
    # @return [Symbol] :zero, :one, :two, :few, :many, :other
    def select_range(start_value, end_value) = ...

    # List of available categories
    # @return [Array<Symbol>]
    def categories = ...

    # Get resolved options
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

## select_range Method

Determines the plural category for a range of numbers. This is equivalent to JavaScript's `Intl.PluralRules.selectRange()`.

```ruby
pr = ICU4X::PluralRules.new(
  ICU4X::Locale.parse("en"),
  provider: provider,
  type: :cardinal
)

pr.select_range(1, 5)   # => :other ("1-5 items")
pr.select_range(0, 1)   # => :other ("0-1 items")
```

### Range Behavior by Language

Different languages have different plural range rules:

```ruby
# Russian
pr_ru = ICU4X::PluralRules.new(
  ICU4X::Locale.parse("ru"),
  provider: provider,
  type: :cardinal
)

pr_ru.select_range(1, 2)   # => :few
pr_ru.select_range(1, 5)   # => :many
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

## Notes

- Supports decimals (e.g., 1.5 is :other in English)
- Category meanings differ by language
- Can be used in combination with Rails I18n pluralization
