# NumberFormat

Locale-aware number formatting. Equivalent to JavaScript's Intl.NumberFormat.

---

## Class Structure

```
ICU4X
└─ NumberFormat
```

---

## ICU4X::NumberFormat

A class for locale-aware number formatting.

### Interface

```ruby
module ICU4X
  class NumberFormat
    # Constructor
    # @param locale [Locale] Locale
    # @param provider [DataProvider] Data provider
    # @param style [Symbol] :decimal, :currency, :percent
    # @param currency [String, nil] Currency code (required when style: :currency)
    # @param use_grouping [Boolean] Use grouping separators (default: true)
    # @param minimum_integer_digits [Integer, nil] Minimum integer digits
    # @param minimum_fraction_digits [Integer, nil] Minimum fraction digits
    # @param maximum_fraction_digits [Integer, nil] Maximum fraction digits
    # @param rounding_mode [Symbol] Rounding mode (default: :half_expand)
    # @raise [Error] If options are invalid
    def initialize(locale, provider:, style: :decimal, currency: nil,
                   use_grouping: true,
                   minimum_integer_digits: nil, minimum_fraction_digits: nil,
                   maximum_fraction_digits: nil, rounding_mode: :half_expand) = ...

    # Format a number
    # @param number [Numeric] Number to format (Integer, Float, BigDecimal)
    # @return [String]
    def format(number) = ...

    # Format a number and return an array of parts
    # @param number [Numeric] Number to format (Integer, Float, BigDecimal)
    # @return [Array<FormattedPart>]
    def format_to_parts(number) = ...

    # Get resolved options
    # @return [Hash]
    def resolved_options = ...
  end
end
```

### Option Details

#### style

| Value | Description | Example (ja-JP) |
|-------|-------------|-----------------|
| `:decimal` | Regular number | 1,234.56 |
| `:currency` | Currency | ￥1,235 |
| `:percent` | Percent | 12% |

#### currency

ISO 4217 currency code. Required when `:currency` style is used.

```ruby
nf = ICU4X::NumberFormat.new(
  locale,
  provider: provider,
  style: :currency,
  currency: "JPY"
)
```

#### Digit Control

```ruby
nf = ICU4X::NumberFormat.new(
  locale,
  provider: provider,
  minimum_integer_digits: 3,     # 001, 012, 123
  minimum_fraction_digits: 2,    # 1.00, 1.20
  maximum_fraction_digits: 4     # 1.2345 (rounded beyond this)
)
```

#### rounding_mode

Rounding mode used with `maximum_fraction_digits`. Default is `:half_expand` (same as Intl.NumberFormat).

| Value | Description | Example (0 digits) |
|-------|-------------|-------------------|
| `:half_expand` | Round half away from zero (default) | 2.5 → 3, -2.5 → -3 |
| `:half_even` | Round half to even (banker's rounding) | 2.5 → 2, 3.5 → 4 |
| `:half_trunc` | Round half toward zero | 2.5 → 2, -2.5 → -2 |
| `:half_ceil` | Round half toward +∞ | 2.5 → 3, -2.5 → -2 |
| `:half_floor` | Round half toward -∞ | 2.5 → 2, -2.5 → -3 |
| `:ceil` | Round toward +∞ | 2.1 → 3, -2.9 → -2 |
| `:floor` | Round toward -∞ | 2.9 → 2, -2.1 → -3 |
| `:expand` | Round away from zero | 2.1 → 3, -2.1 → -3 |
| `:trunc` | Round toward zero | 2.9 → 2, -2.9 → -2 |

```ruby
nf = ICU4X::NumberFormat.new(
  locale,
  provider: provider,
  maximum_fraction_digits: 0,
  rounding_mode: :half_even
)
nf.format(2.5)  # => "2"
nf.format(3.5)  # => "4"
```

---

## Usage Examples

### Regular Numbers

```ruby
provider = ICU4X::DataProvider.from_blob(Pathname.new("data/i18n.blob"))
locale = ICU4X::Locale.parse("ja-JP")

nf = ICU4X::NumberFormat.new(locale, provider: provider)
nf.format(1_234_567.89)
# => "1,234,567.89"
```

### Currency

```ruby
nf = ICU4X::NumberFormat.new(
  locale,
  provider: provider,
  style: :currency,
  currency: "JPY"
)

nf.format(1_234_567)
# => "￥1,234,567"

# For USD
nf_usd = ICU4X::NumberFormat.new(
  ICU4X::Locale.parse("en-US"),
  provider: provider,
  style: :currency,
  currency: "USD"
)

nf_usd.format(1234.56)
# => "$1,234.56"
```

### Percent

```ruby
nf = ICU4X::NumberFormat.new(
  locale,
  provider: provider,
  style: :percent
)

nf.format(0.25)
# => "25%"

nf.format(1.5)
# => "150%"
```

### BigDecimal Support

```ruby
require "bigdecimal"

nf = ICU4X::NumberFormat.new(locale, provider: provider)
nf.format(BigDecimal("12345678901234567890.123456789"))
# => "12,345,678,901,234,567,890.123456789"
```

---

## Numbering System

Specify a numbering system using BCP 47 locale extensions (`-u-nu-xxx`).

### Available Numbering Systems

| Code | Name | Example |
|------|------|---------|
| `latn` | Latin (default) | 0, 1, 2, 3 |
| `arab` | Arabic-Indic | ٠, ١, ٢, ٣ |
| `hanidec` | Han decimal | 〇, 一, 二, 三 |
| `thai` | Thai | ๐, ๑, ๒, ๓ |
| `deva` | Devanagari | ०, १, २, ३ |
| `jpan` | Japanese | Not supported |

### Examples

```ruby
# Han decimal numerals (Chinese/Japanese)
locale = ICU4X::Locale.parse("ja-JP-u-nu-hanidec")
nf = ICU4X::NumberFormat.new(locale, provider: provider)
nf.format(1234)
# => "一,二三四"

# Arabic-Indic numerals
locale = ICU4X::Locale.parse("ar-EG-u-nu-arab")
nf = ICU4X::NumberFormat.new(locale, provider: provider)
nf.format(1234)
# => "١٬٢٣٤"

# Override default to Latin numerals
locale = ICU4X::Locale.parse("ar-EG-u-nu-latn")
nf = ICU4X::NumberFormat.new(locale, provider: provider)
nf.format(1234)
# => "1,234"

# Thai numerals
locale = ICU4X::Locale.parse("th-TH-u-nu-thai")
nf = ICU4X::NumberFormat.new(locale, provider: provider)
nf.format(1234)
# => "๑,๒๓๔"
```

---

## Numeric Type Conversion

### Supported Ruby Types

| Ruby Type | Conversion Method | Notes |
|-----------|-------------------|-------|
| `Integer` | Direct support | Arbitrary precision OK |
| `Float` | Via string | Be cautious of rounding errors |
| `BigDecimal` | `to_s("F")` | Convert to fixed-point format |

---

## format_to_parts

Break down formatted output into typed parts. Useful for custom styling or processing of individual components.

### Part Types

| Type | Description | Example |
|------|-------------|---------|
| `:integer` | Integer part | "1,234" |
| `:fraction` | Fractional part | "56" |
| `:decimal` | Decimal separator | "." |
| `:group` | Grouping separator | "," |
| `:minus_sign` | Negative sign | "-" |
| `:plus_sign` | Positive sign | "+" |
| `:literal` | Other characters | " " |

### Example

```ruby
nf = ICU4X::NumberFormat.new(
  ICU4X::Locale.parse("en-US"),
  provider: provider
)

parts = nf.format_to_parts(-1234.56)
# => [
#   #<ICU4X::FormattedPart type=:minus_sign value="-">,
#   #<ICU4X::FormattedPart type=:integer value="1,234">,
#   #<ICU4X::FormattedPart type=:decimal value=".">,
#   #<ICU4X::FormattedPart type=:fraction value="56">
# ]

# Reconstruct the formatted string
parts.map(&:value).join
# => "-1,234.56"
```

### Limitations

For `style: :percent` and `style: :currency`, the current ICU4X experimental formatters do not provide part annotations. These styles return a single `:literal` part containing the entire formatted string.

```ruby
# Percent style - returns single literal part
nf = ICU4X::NumberFormat.new(locale, provider: provider, style: :percent)
nf.format_to_parts(0.25)
# => [#<ICU4X::FormattedPart type=:literal value="25%">]

# Currency style - returns single literal part
nf = ICU4X::NumberFormat.new(locale, provider: provider, style: :currency, currency: "USD")
nf.format_to_parts(100)
# => [#<ICU4X::FormattedPart type=:literal value="$100">]
```

