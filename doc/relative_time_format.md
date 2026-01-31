# RelativeTimeFormat

Locale-aware relative time formatting. Equivalent to JavaScript's Intl.RelativeTimeFormat.

---

## Class Structure

```
ICU4X
└─ RelativeTimeFormat
```

---

## ICU4X::RelativeTimeFormat

A class for formatting relative time expressions (e.g., "3 days ago", "in 2 hours").

### Interface

```ruby
module ICU4X
  class RelativeTimeFormat
    # Constructor
    # @param locale [Locale] Locale
    # @param provider [DataProvider] Data provider
    # @param style [Symbol] :long (default), :short, :narrow
    # @param numeric [Symbol] :always (default), :auto
    # @raise [ArgumentError] If style or numeric is invalid
    # @raise [Error] If data loading fails
    def initialize(locale, provider:, style: :long, numeric: :always) = ...

    # Format relative time
    # @param value [Integer] The relative time value (negative = past, positive = future)
    # @param unit [Symbol] :second, :minute, :hour, :day, :week, :month, :quarter, :year
    # @return [String]
    # @raise [ArgumentError] If unit is invalid
    def format(value, unit) = ...

    # Format relative time and return an array of parts
    # @param value [Integer] The relative time value (negative = past, positive = future)
    # @param unit [Symbol] :second, :minute, :hour, :day, :week, :month, :quarter, :year
    # @return [Array<FormattedPart>]
    # @raise [ArgumentError] If unit is invalid
    def format_to_parts(value, unit) = ...

    # Get resolved options
    # @return [Hash]
    def resolved_options = ...
  end
end
```

---

## style Option

| Value | Description | Example (-3, :day in en) |
|-------|-------------|--------------------------|
| `:long` | Full words (default) | "3 days ago" |
| `:short` | Abbreviated | "3 days ago" |
| `:narrow` | Minimal | "3d ago" |

---

## numeric Option

| Value | Description | Example (-1, :day in en) |
|-------|-------------|--------------------------|
| `:always` | Always use numbers (default) | "1 day ago" |
| `:auto` | Use words when available | "yesterday" |

---

## unit Option

| Value | Description |
|-------|-------------|
| `:second` | Seconds |
| `:minute` | Minutes |
| `:hour` | Hours |
| `:day` | Days |
| `:week` | Weeks |
| `:month` | Months |
| `:quarter` | Quarters |
| `:year` | Years |

---

## Usage Examples

### Basic Relative Time

```ruby
provider = ICU4X::DataProvider.from_blob(Pathname.new("data/i18n.blob"))
locale = ICU4X::Locale.parse("en-US")

rtf = ICU4X::RelativeTimeFormat.new(locale, provider: provider)

# Past
rtf.format(-3, :day)    # => "3 days ago"
rtf.format(-1, :hour)   # => "1 hour ago"
rtf.format(-2, :week)   # => "2 weeks ago"

# Future
rtf.format(2, :day)     # => "in 2 days"
rtf.format(1, :month)   # => "in 1 month"
rtf.format(5, :minute)  # => "in 5 minutes"
```

### Numeric vs Auto

```ruby
# numeric: :always (default)
rtf = ICU4X::RelativeTimeFormat.new(locale, provider: provider)
rtf.format(-1, :day)   # => "1 day ago"
rtf.format(0, :day)    # => "in 0 days"
rtf.format(1, :day)    # => "in 1 day"

# numeric: :auto
rtf_auto = ICU4X::RelativeTimeFormat.new(locale, provider: provider, numeric: :auto)
rtf_auto.format(-1, :day)   # => "yesterday"
rtf_auto.format(0, :day)    # => "today"
rtf_auto.format(1, :day)    # => "tomorrow"
rtf_auto.format(-2, :day)   # => "2 days ago" (no special word for -2)
```

### Style Variations

```ruby
# Short style
rtf_short = ICU4X::RelativeTimeFormat.new(locale, provider: provider, style: :short)
rtf_short.format(-3, :hour)  # => "3 hr. ago"

# Narrow style
rtf_narrow = ICU4X::RelativeTimeFormat.new(locale, provider: provider, style: :narrow)
rtf_narrow.format(-3, :hour)  # => "3h ago"
```

### Japanese Locale

```ruby
locale_ja = ICU4X::Locale.parse("ja")
rtf = ICU4X::RelativeTimeFormat.new(locale_ja, provider: provider)

rtf.format(-3, :day)    # => "3 日前"
rtf.format(1, :week)    # => "1 週間後"
rtf.format(-2, :month)  # => "2 か月前"

# With numeric: :auto
rtf_auto = ICU4X::RelativeTimeFormat.new(locale_ja, provider: provider, numeric: :auto)
rtf_auto.format(-1, :day)  # => "昨日"
rtf_auto.format(1, :day)   # => "明日"
```

### All Time Units

```ruby
rtf = ICU4X::RelativeTimeFormat.new(locale, provider: provider)

rtf.format(-30, :second)   # => "30 seconds ago"
rtf.format(15, :minute)    # => "in 15 minutes"
rtf.format(-2, :hour)      # => "2 hours ago"
rtf.format(3, :day)        # => "in 3 days"
rtf.format(-1, :week)      # => "1 week ago"
rtf.format(6, :month)      # => "in 6 months"
rtf.format(-2, :quarter)   # => "2 quarters ago"
rtf.format(1, :year)       # => "in 1 year"
```

---

## format_to_parts

Break down formatted output into typed parts.

### Part Types

| Type | Description | Example |
|------|-------------|---------|
| `:literal` | The entire formatted string | "3 days ago" |

NOTE: The current ICU4X experimental RelativeTimeFormatter does not provide separate part annotations for the numeric value. The entire formatted string is returned as a single `:literal` part.

### Example

```ruby
rtf = ICU4X::RelativeTimeFormat.new(locale, provider: provider)
parts = rtf.format_to_parts(-3, :day)
# => [#<ICU4X::FormattedPart type=:literal value="3 days ago">]

# Reconstruct the formatted string
parts.map(&:value).join  # => "3 days ago"
```

---

## Notes

- Negative values represent past time ("X ago")
- Positive values represent future time ("in X")
- Zero is treated as future ("in 0 days")
- The `numeric: :auto` option uses special words like "yesterday", "today", "tomorrow" when available
- Relative time patterns vary by locale (e.g., Japanese uses "前" for past and "後" for future)
