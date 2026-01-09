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
    # @param calendar [Symbol] :gregory, :japanese, :buddhist, :chinese, :hebrew, :islamic, :persian, :indian, :ethiopian, :coptic, :roc, :dangi
    # @raise [Error] If options are invalid
    def initialize(locale, provider:, date_style: nil, time_style: nil, time_zone: nil, calendar: nil) = ...

    # Format a time
    # @param time [Time, #to_time] Time to format (or any object responding to #to_time)
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

Specify the calendar system to use for formatting.

| Value | Description |
|-------|-------------|
| `:gregory` | Gregorian calendar (default) |
| `:japanese` | Japanese Imperial calendar (Reiwa, Heisei, etc.) |
| `:buddhist` | Buddhist calendar (Thai Buddhist Era) |
| `:chinese` | Traditional Chinese calendar |
| `:hebrew` | Hebrew calendar |
| `:islamic` | Islamic (Hijri) calendar |
| `:persian` | Persian (Solar Hijri) calendar |
| `:indian` | Indian National calendar |
| `:ethiopian` | Ethiopian calendar |
| `:coptic` | Coptic calendar |
| `:roc` | Republic of China (Minguo) calendar |
| `:dangi` | Korean traditional calendar |

If not specified, defaults based on locale preferences.

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

# Date objects are also supported (via #to_time)
dtf.format(Date.new(2025, 12, 28))
# => "2025年12月28日 0:00"
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

### Calendar Examples

```ruby
# Japanese calendar (Reiwa era)
dtf = ICU4X::DateTimeFormat.new(
  locale,
  provider: provider,
  date_style: :long,
  calendar: :japanese
)
dtf.format(Time.utc(2025, 12, 28))
# => "December 28, 7 Reiwa" (in en-US locale)

# Buddhist calendar (BE 2568 = CE 2025)
dtf = ICU4X::DateTimeFormat.new(
  locale,
  provider: provider,
  date_style: :long,
  calendar: :buddhist
)
dtf.format(Time.utc(2025, 12, 28))
# => "December 28, 2568 BE"

# ROC calendar (Minguo 114 = CE 2025)
dtf = ICU4X::DateTimeFormat.new(
  locale,
  provider: provider,
  date_style: :long,
  calendar: :roc
)
dtf.format(Time.utc(2025, 12, 28))
# => "December 28, 114 Minguo"
```

### Resolved Options

```ruby
dtf.resolved_options
# => {
#   locale: "ja-JP",
#   calendar: :japanese,
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

---

## Known Limitations

### CLDR Data Differences from Other Implementations

ICU4X uses CLDR (Common Locale Data Repository) data, but the formatting output may differ from other implementations like JavaScript's `Intl.DateTimeFormat` (V8/Node.js).

Example with Japanese locale and Chinese calendar:

| Implementation | CLDR Version | Output |
|----------------|--------------|--------|
| Node.js (V8 ICU) | CLDR 47 | 乙巳年十一月一二日 (day in Chinese numerals) |
| ICU4X 2.1.1 | CLDR 48 | 乙巳年十一月9日 (day in Arabic numerals) |

The CLDR data specifies `_numbers: "hanidec"` for Chinese calendar date formats in Japanese locale, indicating that Han decimal numerals (一、二、三...) should be used. However, ICU4X does not apply this numbering system attribute, resulting in Arabic numerals for the day field. This is an ICU4X implementation difference, not a CLDR data issue. This is not controllable at the gem level.

