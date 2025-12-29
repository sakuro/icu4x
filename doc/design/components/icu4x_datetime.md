# DateTimeFormat

Date/time formatting functionality. Equivalent to JavaScript Intl.DateTimeFormat.

**Status**: Future implementation

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
icu_datetime = "2.0"
icu_calendar = "2.0"
icu_timezone = "2.0"
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

- Completed on ICU4X side without depending on Ruby's `Time` / `Date`
- Timezone conversion is handled by ICU4X
- Calendar initially supports Gregorian only; `calendar:` option is for future expansion

---

## Calendar Support

### Current Support Status

| Calendar | Status | Notes |
|----------|--------|-------|
| `:gregory` | Planned | Gregorian calendar (default) |
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

### Policy: Full Delegation to ICU4X

Timezone processing is completed on the ICU4X side. The Ruby tzinfo gem is not used.

### ICU4X Timezone Features

ICU4X includes data derived from the IANA Time Zone Database:

| Component | Role |
|-----------|------|
| `TimeZoneIdMapper` | IANA → BCP-47 conversion (e.g., "Asia/Tokyo" → "jptyo") |
| `MetazoneCalculator` | Metazone calculation based on date/time |
| `CustomTimeZone` | Holds offset, ID, metazone, and daylight saving time |

**Note**: ICU4X uses BCP-47 format internally. The Ruby API accepts IANA format and converts on the Rust side.

### Processing Flow

```
Ruby side                        Rust side (ICU4X)
─────────────────────────────────────────────────────────
time_zone: "Asia/Tokyo"    →    Convert to BCP-47 via TimeZoneIdMapper
                           →    Get timezone data from DataProvider
                           →    Calculate metazone via MetazoneCalculator
                           →    Execute formatting
                           ←    Return result string
```

### Timezone Data in DataGenerator

When using timezone functionality, the following markers are required in DataGenerator:

```ruby
ICU4X::DataGenerator.export(
  locales: %w[ja en],
  markers: [:datetime],  # Includes timezone data
  format: :blob,
  output: Pathname.new("data/i18n.blob")
)
```

### Rationale

| Perspective | ICU4X Delegation | Using tzinfo |
|-------------|------------------|--------------|
| Dependencies | No additional gem needed | tzinfo required |
| Consistency | Single data source | Inconsistency risk |
| Performance | Completed on Rust side | Ruby/Rust data transfer |
| Compatibility | Same as JavaScript Intl | Custom approach |

---

## Related

- [icu4x.md](./icu4x.md)
- [data_provider.md](./data_provider.md)
- [icu4x_ruby_design.md](../icu4x_ruby_design.md) - Sections 5, 6
- [icu_timezone - Docs.rs](https://docs.rs/icu_timezone/latest/icu_timezone/) - ICU4X timezone crate
