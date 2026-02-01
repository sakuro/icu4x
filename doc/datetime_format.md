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
    # @param year [Symbol, nil] :numeric, :two_digit (component option)
    # @param month [Symbol, nil] :numeric, :two_digit, :long, :short, :narrow (component option)
    # @param day [Symbol, nil] :numeric, :two_digit (component option)
    # @param weekday [Symbol, nil] :long, :short, :narrow (component option)
    # @param hour [Symbol, nil] :numeric, :two_digit (component option)
    # @param minute [Symbol, nil] :numeric, :two_digit (component option)
    # @param second [Symbol, nil] :numeric, :two_digit (component option)
    # @param time_zone [String, nil] IANA timezone name (e.g., "Asia/Tokyo")
    # @param calendar [Symbol] :gregory, :japanese, :buddhist, :chinese, :hebrew, :islamic, :persian, :indian, :ethiopian, :coptic, :roc, :dangi
    # @param hour_cycle [Symbol, nil] :h11 (0-11), :h12 (1-12), :h23 (0-23)
    # @raise [Error] If options are invalid
    def initialize(locale, provider: nil, date_style: nil, time_style: nil,
                   year: nil, month: nil, day: nil, weekday: nil,
                   hour: nil, minute: nil, second: nil,
                   time_zone: nil, calendar: nil, hour_cycle: nil) = ...

    # Format a time
    # @param time [Time, #to_time] Time to format (or any object responding to #to_time)
    # @return [String]
    def format(time) = ...

    # Format a time and return an array of parts
    # @param time [Time, #to_time] Time to format (or any object responding to #to_time)
    # @return [Array<FormattedPart>]
    def format_to_parts(time) = ...

    # Get resolved options
    # @return [Hash]
    def resolved_options = ...
  end
end
```

### Option Details

There are two ways to specify which date/time components to include:

1. **Style options** (`date_style`, `time_style`) - Use predefined formatting patterns
2. **Component options** (`year`, `month`, `day`, `weekday`, `hour`, `minute`, `second`) - Specify individual components

At least one style option or component option must be specified. Style options and component options are **mutually exclusive** - you cannot use both in the same formatter.

#### date_style / time_style

At least one must be specified when using style options.

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

#### hour_cycle

Control 12-hour vs 24-hour time display format.

| Value | Range | Midnight | Noon | Usage |
|-------|-------|----------|------|-------|
| `:h12` | 1-12 | 12:00 AM | 12:00 PM | US, etc. |
| `:h11` | 0-11 | 0:00 AM | 0:00 PM | Some Japanese systems |
| `:h23` | 0-23 | 00:00 | 12:00 | Europe, Japan, etc. |

NOTE: `:h24` (1-24) is not supported as ICU4X does not implement this hour cycle.

```ruby
dtf = ICU4X::DateTimeFormat.new(
  locale,
  provider: provider,
  time_style: :short,
  hour_cycle: :h23
)
dtf.format(Time.utc(2025, 1, 1, 0, 30))  # => "00:30:00"
```

#### Component Options

Component options allow you to specify which date/time fields to include in the output, similar to JavaScript's `Intl.DateTimeFormat`.

| Option | Values | Description |
|--------|--------|-------------|
| `year` | `:numeric`, `:two_digit` | Include year |
| `month` | `:numeric`, `:two_digit`, `:long`, `:short`, `:narrow` | Include month |
| `day` | `:numeric`, `:two_digit` | Include day of month |
| `weekday` | `:long`, `:short`, `:narrow` | Include day of week |
| `hour` | `:numeric`, `:two_digit` | Include hour |
| `minute` | `:numeric`, `:two_digit` | Include minute |
| `second` | `:numeric`, `:two_digit` | Include second |

**Important notes:**
- Component options and style options (`date_style`/`time_style`) are mutually exclusive
- The order of components in the output is determined by the locale (via CLDR data), not by the order of options
- **Text-based month/weekday options** (`:long`, `:short`, `:narrow`) all produce spelled-out formats to ensure proper localized formatting across all locales. See [Limitation: Text-based component options](#limitation-text-based-component-options) for details.

```ruby
# All numeric options → short format
dtf = ICU4X::DateTimeFormat.new(
  locale,
  provider: provider,
  year: :numeric,
  month: :numeric,
  day: :numeric
)
dtf.format(Time.utc(2025, 12, 28))  # => "12/28/25" (en-US)
                                     # => "2025/12/28" (ja-JP)

# month: :long → spelled-out format
dtf = ICU4X::DateTimeFormat.new(
  locale,
  provider: provider,
  month: :long,
  day: :numeric
)
dtf.format(Time.utc(2025, 12, 28))  # => "December 28" (en-US)

# weekday: :long → spelled-out format
dtf = ICU4X::DateTimeFormat.new(
  locale,
  provider: provider,
  weekday: :long
)
dtf.format(Time.utc(2025, 12, 28))  # => "Sunday" (en-US)
                                     # => "日曜日" (ja-JP)

# year: :numeric, month: :short → spelled-out format (proper locale-aware pattern)
dtf = ICU4X::DateTimeFormat.new(
  ICU4X::Locale.parse("ja-JP"),
  provider: provider,
  year: :numeric,
  month: :short
)
dtf.format(Time.utc(2025, 12, 28))  # => "2025年12月" (not "2025/12")
```

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

### Numbering System

Specify a numbering system using BCP 47 locale extensions (`-u-nu-xxx`):

```ruby
# Han decimal numerals
locale = ICU4X::Locale.parse("ja-JP-u-nu-hanidec")
dtf = ICU4X::DateTimeFormat.new(locale, provider: provider, date_style: :long)
dtf.format(Time.utc(2025, 12, 28))
# => "二〇二五年一二月二八日"

# Thai numerals
locale = ICU4X::Locale.parse("th-TH-u-nu-thai")
dtf = ICU4X::DateTimeFormat.new(locale, provider: provider, date_style: :short)
dtf.format(Time.utc(2025, 12, 28))
# => "๒๘/๑๒/๖๘"
```

See [NumberFormat - Numbering System](number_format.md#numbering-system) for available numbering systems.

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

## format_to_parts

Break down formatted output into typed parts. Useful for custom styling or processing of individual components.

### Part Types

| Type | Description | Example |
|------|-------------|---------|
| `:year` | Year | "2025" |
| `:month` | Month | "January", "12" |
| `:day` | Day of month | "28" |
| `:weekday` | Day of week | "Sunday" |
| `:hour` | Hour | "9" |
| `:minute` | Minute | "30" |
| `:second` | Second | "45" |
| `:day_period` | AM/PM | "AM", "午前" |
| `:era` | Era name | "令和", "Reiwa", "BE" |
| `:time_zone_name` | Timezone name | "JST" |
| `:literal` | Separators and punctuation | " ", "/", "年" |

### Example

```ruby
dtf = ICU4X::DateTimeFormat.new(
  ICU4X::Locale.parse("ja-JP"),
  provider: provider,
  date_style: :long,
  calendar: :japanese
)

parts = dtf.format_to_parts(Time.utc(2025, 1, 31))
# => [
#   #<ICU4X::FormattedPart type=:era value="令和">,
#   #<ICU4X::FormattedPart type=:year value="7">,
#   #<ICU4X::FormattedPart type=:literal value="年">,
#   #<ICU4X::FormattedPart type=:month value="1">,
#   #<ICU4X::FormattedPart type=:literal value="月">,
#   #<ICU4X::FormattedPart type=:day value="31">,
#   #<ICU4X::FormattedPart type=:literal value="日">
# ]

# Reconstruct the formatted string
parts.map(&:value).join
# => "令和7年1月31日"
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

### Limitation: Text-based component options

When using component options with text-based month (`:long`, `:short`, `:narrow`) or weekday (`:long`, `:short`, `:narrow`) values, **all three produce the same spelled-out format**.

| Component | JavaScript Intl | ICU4X Ruby |
|-----------|-----------------|------------|
| `month: 'short'` | "Feb" (en-US), "2月" (ja-JP) | "February" (en-US), "2月" (ja-JP) |
| `month: 'long'` | "February" (en-US), "2月" (ja-JP) | "February" (en-US), "2月" (ja-JP) |
| `month: 'narrow'` | "F" (en-US), "2月" (ja-JP) | "February" (en-US), "2月" (ja-JP) |

**Why this limitation exists:**

ICU4X's field sets use a single "length" parameter to control the overall format pattern, not individual component widths. When using shorter lengths (medium/short), some locales produce numeric formats instead of text:

- `Length::Medium` in Japanese: "2026/02" (numeric with slashes)
- `Length::Long` in Japanese: "2026年2月" (text with 年/月)

To ensure proper localized text formatting across all locales (especially non-Latin scripts), this gem uses `Length::Long` whenever text-based month or weekday options are specified.

**Workaround:**

If you need abbreviated month names in English-like locales, consider:
1. Using `date_style: :medium` instead of component options
2. Post-processing the output if abbreviation is critical

