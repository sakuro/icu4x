# DurationFormat

Locale-aware duration formatting. Equivalent to JavaScript's Intl.DurationFormat.

---

## Class Structure

```
ICU4X
└─ DurationFormat
```

---

## ICU4X::DurationFormat

A class for formatting durations (time spans) in a locale-aware manner.

### Interface

```ruby
module ICU4X
  class DurationFormat
    # Constructor
    # @param locale [Locale] Locale
    # @param provider [DataProvider] Data provider
    # @param style [Symbol] :long (default), :short, :narrow, :digital
    # @raise [ArgumentError] If style is invalid
    # @raise [TypeError] If provider is not a DataProvider
    # @raise [Error] If data loading fails
    def initialize(locale, provider:, style: :long) = ...

    # Format a duration
    # @param duration [Hash] Duration components
    # @option duration [Integer] :years
    # @option duration [Integer] :months
    # @option duration [Integer] :weeks
    # @option duration [Integer] :days
    # @option duration [Integer] :hours
    # @option duration [Integer] :minutes
    # @option duration [Integer] :seconds
    # @option duration [Integer] :milliseconds
    # @option duration [Integer] :microseconds
    # @option duration [Integer] :nanoseconds
    # @return [String]
    # @raise [ArgumentError] If duration is empty or has negative values
    def format(duration) = ...

    # Get resolved options
    # @return [Hash]
    def resolved_options = ...
  end
end
```

---

## style Option

| Value | Description | Example (1h 30m in en) |
|-------|-------------|------------------------|
| `:long` | Full words (default) | "1 hour, 30 minutes" |
| `:short` | Abbreviated | "1 hr, 30 min" |
| `:narrow` | Minimal | "1h 30m" |
| `:digital` | Digital clock format | "1:30:00" |

---

## duration Hash Keys

| Key | Type | Description |
|-----|------|-------------|
| `:years` | Integer | Number of years |
| `:months` | Integer | Number of months |
| `:weeks` | Integer | Number of weeks |
| `:days` | Integer | Number of days |
| `:hours` | Integer | Number of hours |
| `:minutes` | Integer | Number of minutes |
| `:seconds` | Integer | Number of seconds |
| `:milliseconds` | Integer | Number of milliseconds |
| `:microseconds` | Integer | Number of microseconds |
| `:nanoseconds` | Integer | Number of nanoseconds |

All keys are optional. At least one key with a non-zero value should be provided.

---

## Usage Examples

### Basic Duration Formatting

```ruby
provider = ICU4X::DataProvider.from_blob(Pathname.new("data/i18n.blob"))
locale = ICU4X::Locale.parse("en-US")

df = ICU4X::DurationFormat.new(locale, provider: provider)

df.format(hours: 1, minutes: 30)
# => "1 hour, 30 minutes"

df.format(days: 2, hours: 5, minutes: 15)
# => "2 days, 5 hours, 15 minutes"
```

### Style Variations

```ruby
# Short style
df_short = ICU4X::DurationFormat.new(locale, provider: provider, style: :short)
df_short.format(hours: 2, minutes: 45)
# => "2 hr, 45 min"

# Narrow style
df_narrow = ICU4X::DurationFormat.new(locale, provider: provider, style: :narrow)
df_narrow.format(hours: 2, minutes: 45)
# => "2h 45m"

# Digital style
df_digital = ICU4X::DurationFormat.new(locale, provider: provider, style: :digital)
df_digital.format(hours: 1, minutes: 30, seconds: 45)
# => "1:30:45"
```

### Japanese Locale

```ruby
locale_ja = ICU4X::Locale.parse("ja")
df = ICU4X::DurationFormat.new(locale_ja, provider: provider)

df.format(hours: 2, minutes: 15)
# => "2時間15分"

df.format(days: 3, hours: 12)
# => "3日12時間"
```

### Fine-grained Time Units

```ruby
df.format(seconds: 5, milliseconds: 250)
# => "5 seconds, 250 milliseconds"

df.format(years: 1, months: 6)
# => "1 year, 6 months"
```

---

## Notes

- All duration values must be non-negative integers
- At least one duration component must be non-zero
- The digital style (`1:30:45`) is primarily designed for hours, minutes, and seconds
- Duration formatting follows locale-specific conventions for separators and unit names
