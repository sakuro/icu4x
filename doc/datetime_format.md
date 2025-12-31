# DateTimeFormat

Locale-aware date/time formatting. Equivalent to JavaScript's Intl.DateTimeFormat.

---

## Class Structure

```
ICU4X
└─ DateTimeFormat
```

---

## ICU4X::DateTimeFormat

A class for locale-aware date/time formatting.

### Interface

```ruby
module ICU4X
  class DateTimeFormat
    # Constructor
    # @param locale [Locale] Locale
    # @param provider [DataProvider] Data provider
    # @param date_style [Symbol, nil] :full, :long, :medium, :short
    # @param time_style [Symbol, nil] :full, :long, :medium, :short
    # @param time_zone [String, nil] IANA timezone name (e.g., "Asia/Tokyo")
    # @param calendar [Symbol] :gregory (only gregory is currently supported)
    # @raise [Error] If options are invalid
    def initialize(locale, provider:, date_style: nil, time_style: nil, time_zone: nil, calendar: :gregory) = ...

    # Format a time
    # @param time [Time] Time to format
    # @return [String]
    def format(time) = ...

    # Get resolved options
    # @return [Hash]
    def resolved_options = ...
  end
end
```

### Option Details

#### date_style / time_style

At least one must be specified.

| Value | Description | Example (ja-JP) |
|-------|-------------|------------------|
| `:full` | Full format | 2025年12月28日日曜日 |
| `:long` | Long format | 2025年12月28日 |
| `:medium` | Medium format | 2025/12/28 |
| `:short` | Short format | 25/12/28 |

#### time_zone

Specify an IANA timezone name (e.g., "Asia/Tokyo", "America/New_York").

```ruby
dtf = ICU4X::DateTimeFormat.new(
  locale,
  provider: provider,
  date_style: :long,
  time_zone: "America/New_York"
)
```

**Default: UTC**. When not specified, processed as UTC.

#### calendar

Currently only `:gregory` (Gregorian calendar) is supported. Specifying other values raises an error.

---

## Usage Examples

### Basic Formatting

```ruby
provider = ICU4X::DataProvider.from_blob(Pathname.new("data/i18n.blob"))
locale = ICU4X::Locale.parse("ja-JP")

dtf = ICU4X::DateTimeFormat.new(
  locale,
  provider: provider,
  date_style: :long,
  time_style: :short
)

dtf.format(Time.utc(2025, 12, 28, 9, 30))
# => "2025年12月28日 9:30"
```

### Timezone Conversion

```ruby
dtf = ICU4X::DateTimeFormat.new(
  locale,
  provider: provider,
  date_style: :long,
  time_style: :short,
  time_zone: "Asia/Tokyo"
)

# UTC 2025-12-28 00:00 → Tokyo 2025-12-28 09:00
dtf.format(Time.utc(2025, 12, 28, 0, 0))
# => "2025年12月28日 9:00"
```

### Resolved Options

```ruby
dtf.resolved_options
# => {
#   locale: "ja-JP",
#   calendar: :gregory,
#   date_style: :long,
#   time_style: :short,
#   time_zone: "Asia/Tokyo"
# }
```

---

## Timezone Management

### Implementation: UTC Offset Calculation via jiff crate

Timezone offset calculation uses the [jiff](https://crates.io/crates/jiff) crate instead of ICU4X's internal mechanisms. ICU4X's `VariantOffsetsCalculator` was deprecated in version 2.1.0 as "a bad approximation of a time zone database."

### Processing Flow

```
Ruby side                        Rust side
─────────────────────────────────────────────────────────
time_zone: "Asia/Tokyo"    →    Validate via ICU4X IanaParser
                           →    Create jiff::tz::TimeZone
Time.utc(...)              →    Get Unix timestamp from Ruby Time
                           →    Convert to jiff::Timestamp
                           →    Apply timezone offset via jiff
                           →    Format local datetime with ICU4X
                           ←    Return result string
```

---

## Unimplemented Features

The following features are not implemented due to ICU4X support limitations.

### format_to_parts / FormattedPart

Functionality to break down formatted results into parts. On hold because ICU4X's parts output does not match the expected structure.

```ruby
# Planned API
module ICU4X
  class DateTimeFormat
    FormattedPart = Data.define(:type, :value)

    # @param time [Time] Time to format
    # @return [Array<FormattedPart>]
    def format_to_parts(time) = ...
  end
end
```

### Additional Calendar Support

| Calendar | Status | Notes |
|----------|--------|-------|
| `:gregory` | Implemented | Gregorian calendar (default) |
| `:japanese` | Not implemented | Japanese calendar (Reiwa, Heisei, etc.) |
| Others | Not implemented | Buddhist, Hijri, etc. |

Adding calendars requires regenerating the DataProvider blob data.

