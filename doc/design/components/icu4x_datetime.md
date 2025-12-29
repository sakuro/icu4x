# DateTimeFormat

Date/time formatting functionality. Equivalent to JavaScript Intl.DateTimeFormat.

**Status**: Implemented (format_to_parts pending)

---

## Class Structure

```
ICU4X
└─ DateTimeFormat
   └─ FormattedPart (Data)
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
    # @param calendar [Symbol] :gregory (initially only gregory)
    # @raise [Error] If options are invalid
    def initialize(locale, provider:, date_style: nil, time_style: nil, time_zone: nil, calendar: :gregory) = ...

    # Format
    # @param time [Time] Target to format
    # @return [String]
    def format(time) = ...

    # Format to parts
    # @param time [Time] Target to format
    # @return [Array<FormattedPart>]
    def format_to_parts(time) = ...

    # Resolved options
    # @return [Hash]
    def resolved_options = ...
  end
end
```

### Option Details

#### date_style / time_style

| Value | Description | Japanese Example |
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
  time_zone: "America/New_York"
)
```

**Default: UTC (Coordinated Universal Time)**. When not specified, processed as UTC.

#### calendar

Initially supports only `:gregory` (Gregorian calendar). Plans to add `:japanese` (Japanese calendar) and others in the future.

**Note**: Currently, the `calendar:` option is ignored for values other than `:gregory`.

---

## ICU4X::DateTimeFormat::FormattedPart

A Data class representing parts of the formatted result.

```ruby
module ICU4X
  class DateTimeFormat
    FormattedPart = Data.define(:type, :value)

    # @!attribute [r] type
    #   Part type
    #   @return [Symbol] :year, :month, :day, :weekday, :hour, :minute, :second, :literal, etc.

    # @!attribute [r] value
    #   Part value
    #   @return [String]
  end
end
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
# => "2025年12月28日 18:30" (with time_zone specified)
```

### Formatting to Parts

```ruby
parts = dtf.format_to_parts(Time.utc(2025, 12, 28))
# => [
#   #<data ICU4X::DateTimeFormat::FormattedPart type=:year, value="2025">,
#   #<data ICU4X::DateTimeFormat::FormattedPart type=:literal, value="年">,
#   #<data ICU4X::DateTimeFormat::FormattedPart type=:month, value="12">,
#   #<data ICU4X::DateTimeFormat::FormattedPart type=:literal, value="月">,
#   #<data ICU4X::DateTimeFormat::FormattedPart type=:day, value="28">,
#   #<data ICU4X::DateTimeFormat::FormattedPart type=:literal, value="日">
# ]
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

## Rust Extension

When implemented, will be added to `ext/icu4x/src/`.

### Dependent Crates

```toml
[dependencies]
icu = { version = "2.1", features = ["experimental"] }
jiff = "0.2"  # For timezone offset calculation
```

### Rust Module Structure

```
ext/icu4x/src/
├─ lib.rs              # Entry point (add datetime_format module)
└─ datetime_format.rs  # DateTimeFormat bindings
```

---

## Test Data Generation

```bash
# Test data for datetime
$ icu4x-datagen --locales en,ja --markers datetime --format blob --output spec/fixtures/test.blob
```

---

## Design Notes

- Completed on Rust side without depending on Ruby's `Time` / `Date`
- Timezone conversion uses jiff crate (ICU4X's internal mechanism was deprecated)
- Calendar initially supports Gregorian only; `calendar:` option is for future expansion
- Ruby Time objects are converted to UTC, then to local time via jiff, then formatted with ICU4X

---

## Calendar Support

### Current Support Status

| Calendar | Status | Notes |
|----------|--------|-------|
| `:gregory` | Implemented | Gregorian calendar (default) |
| `:japanese` | Future | Japanese calendar (Reiwa, Heisei, etc.) |
| Others | Future consideration | Buddhist, Hijri, etc. |

### Data Regeneration When Adding Calendars

When adding new calendars (e.g., Japanese calendar), **DataProvider blob data must be regenerated**.

Reasons:
- Each calendar requires specific data (month names, era names, format patterns, etc.)
- Only data for calendars specified during DataGenerator execution is included in the blob
- Existing blobs do not contain data for new calendars

```ruby
# Future API image (when calendar specification option is added)
ICU4X::DataGenerator.export(
  locales: %w[ja en],
  markers: [:datetime],
  calendars: [:gregory, :japanese],  # <- Multiple calendar specification
  format: :blob,
  output: Pathname.new("data/i18n.blob")
)
```

### Impact on Users

When calendar functionality is expanded, users need to:

1. Update the icu4x gem
2. Regenerate blob data including the new calendar
3. Redeploy the blob to the application

---

## Timezone Management

### Implementation: jiff crate for UTC offset calculation

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

### Components Used

| Component | Role |
|-----------|------|
| `icu::time::zone::IanaParser` | Validate IANA timezone names |
| `jiff::tz::TimeZone` | Timezone with IANA Time Zone Database |
| `jiff::Timestamp` | UTC timestamp for offset calculation |
| `icu::datetime::DateTimeFormatter` | Locale-aware formatting |

### Rationale for using jiff

| Perspective | jiff crate | ICU4X internal | tzinfo gem |
|-------------|------------|----------------|------------|
| Accuracy | Full IANA database | Deprecated/approximate | Full IANA database |
| Dependencies | Rust crate only | N/A | Ruby gem required |
| Performance | All in Rust | N/A | Ruby/Rust transfer |
| Maintenance | Actively maintained | Deprecated | Actively maintained |

---

## Related

- [icu4x.md](./icu4x.md)
- [data_provider.md](./data_provider.md)
- [icu4x_ruby_design.md](../icu4x_ruby_design.md) - Sections 5, 6
- [icu_timezone - Docs.rs](https://docs.rs/icu_timezone/latest/icu_timezone/) - ICU4X timezone crate
