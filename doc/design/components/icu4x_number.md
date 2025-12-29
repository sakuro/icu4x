# NumberFormat

Number formatting functionality. Equivalent to JavaScript Intl.NumberFormat.

**Status**: Future implementation

---

## Class Structure

```
ICU4X
└─ NumberFormat
   └─ FormattedPart (Data)
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
    # @param minimum_integer_digits [Integer, nil] Minimum integer digits
    # @param minimum_fraction_digits [Integer, nil] Minimum fraction digits
    # @param maximum_fraction_digits [Integer, nil] Maximum fraction digits
    # @param use_grouping [Boolean] Use grouping separators (default: true)
    # @raise [Error] If options are invalid
    def initialize(locale, provider:, style: :decimal, currency: nil,
                   minimum_integer_digits: nil, minimum_fraction_digits: nil,
                   maximum_fraction_digits: nil, use_grouping: true) = ...

    # Format
    # @param number [Numeric] Target to format (Integer, Float, BigDecimal)
    # @return [String]
    def format(number) = ...

    # Format to parts
    # @param number [Numeric] Target to format
    # @return [Array<FormattedPart>]
    def format_to_parts(number) = ...

    # Resolved options
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

---

## ICU4X::NumberFormat::FormattedPart

A Data class representing parts of the formatted result.

```ruby
module ICU4X
  class NumberFormat
    FormattedPart = Data.define(:type, :value)

    # @!attribute [r] type
    #   Part type
    #   @return [Symbol] :integer, :decimal, :fraction, :group, :currency, :percent, :literal, etc.

    # @!attribute [r] value
    #   Part value
    #   @return [String]
  end
end
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

nf.format(0.1234)
# => "12%"
```

### Formatting to Parts

```ruby
nf = ICU4X::NumberFormat.new(
  locale,
  provider: provider,
  style: :currency,
  currency: "JPY"
)

parts = nf.format_to_parts(1_234_567)
# => [
#   #<data ICU4X::NumberFormat::FormattedPart type=:currency, value="￥">,
#   #<data ICU4X::NumberFormat::FormattedPart type=:integer, value="1">,
#   #<data ICU4X::NumberFormat::FormattedPart type=:group, value=",">,
#   #<data ICU4X::NumberFormat::FormattedPart type=:integer, value="234">,
#   #<data ICU4X::NumberFormat::FormattedPart type=:group, value=",">,
#   #<data ICU4X::NumberFormat::FormattedPart type=:integer, value="567">
# ]
```

### BigDecimal Support

```ruby
require "bigdecimal"

nf = ICU4X::NumberFormat.new(locale, provider: provider)
nf.format(BigDecimal("12345678901234567890.123456789"))
# => "12,345,678,901,234,567,890.123456789"
```

---

## Rust Extension

When implemented, will be added to `ext/icu4x/src/`.

### Dependent Crates

```toml
[dependencies]
icu_decimal = "2.0"
fixed_decimal = "0.5"
```

### Rust Module Structure

```
ext/icu4x/src/
├─ lib.rs             # Entry point (add number_format module)
└─ number_format.rs   # NumberFormat bindings
```

---

## Test Data Generation

```bash
# Test data for number
$ icu4x-datagen --locales en,ja --markers number --format blob --output spec/fixtures/test.blob
```

---

## Design Notes

- Supports arbitrary precision numbers including BigDecimal
- Be cautious of Float rounding errors (BigDecimal recommended for financial use cases)
- Currency rounding rules depend on locale and currency code

---

## Numeric Type Conversion

### Ruby → Rust → ICU4X Flow

```
Ruby side                  Rust side (Magnus)         ICU4X
───────────────────────────────────────────────────────────────
Integer (small)       →    i64                   →
Integer (large)       →    RBignum               →    FixedDecimal
Float                 →    f64                   →    (via FromStr)
Rational              →    Manual conversion     →
BigDecimal            →    Via string            →
```

### Supported Ruby Types

| Ruby Type | Conversion Method | Notes |
|-----------|-------------------|-------|
| `Integer` | Direct support | Arbitrary precision OK |
| `Float` | Via string | Be cautious of rounding errors |
| `Rational` | `to_d.to_s("F")` | Rational → BigDecimal → String |
| `BigDecimal` | `to_s("F")` | Convert to string in fixed-point format |

### Implementation Strategy: Unified via String

Since ICU4X's `FixedDecimal` implements `FromStr`, converting **via string** is the safest and most versatile approach.

#### Ruby Side Preprocessing

```ruby
module ICU4X
  class NumberFormat
    def format(number)
      str = case number
            when BigDecimal then number.to_s("F")
            when Rational then number.to_d.to_s("F")
            else number.to_s
            end
      native_format(str)
    end
  end
end
```

#### Rust Side Processing

```rust
fn native_format(&self, s: String) -> Result<String, magnus::Error> {
    let decimal = FixedDecimal::from_str(&s)
        .map_err(|e| magnus::Error::new(...))?;

    let formatted = self.formatter.format(&decimal);
    Ok(formatted.to_string())
}
```

### ICU4X FixedDecimal Creation Methods

| Source Type | Conversion Method | Notes |
|-------------|-------------------|-------|
| `i32`, `i64`, `u32`, `u64` | `From` trait | Direct conversion OK |
| `f64` | `from_f64(value, precision)` | Requires `ryu` feature, returns `Result` |
| `&str` | `FromStr` trait | **Recommended** |

### Type-Specific Considerations

| Ruby Type | Considerations |
|-----------|----------------|
| `Integer` | Ruby has arbitrary precision, so large numbers are OK |
| `Float` | IEEE 754 limitations; rounding errors visible via `to_s` |
| `Rational` | `to_s` → `"1/3"` format, so must use `to_d` first |
| `BigDecimal` | `to_s("F")` → `"123.456"` format; default `to_s` → `"0.123456E3"` |

---

## Related

- [icu4x.md](./icu4x.md)
- [data_provider.md](./data_provider.md)
- [icu4x_ruby_design.md](../icu4x_ruby_design.md) - Section 6
- [magnus - GitHub](https://github.com/matsadler/magnus) - Ruby-Rust bindings
- [fixed_decimal - Docs.rs](https://docs.rs/fixed_decimal/latest/fixed_decimal/) - ICU4X numeric representation
- [icu::decimal - Docs.rs](https://docs.rs/icu/latest/icu/decimal/) - ICU4X number formatting
