# Data

Locale data management for ICU4X formatters.

---

## Class Structure

```
ICU4X
├─ DataProvider
└─ DataGenerator
```

---

## Data Contents

Data supplied by DataProvider is derived from **CLDR (Common Locale Data Repository)**:

| Category | Content Examples |
|----------|------------------|
| datetime | Month names, weekday names, date patterns, timezone names |
| number | Digit symbols, currency symbols, percent format |
| plurals | Plural rules (one/few/many/other determination per language) |
| calendar | Calendar systems (Gregorian, Japanese, etc.) |

---

## Data Supply Approach

**User-generated data approach** is adopted:

1. Users generate data using `ICU4X::DataGenerator` API
2. Place generated blob file in application
3. Load at runtime with `DataProvider.from_blob`

| Traditional Approach | This Design |
|---------------------|-------------|
| Bundle all locale data with gem | Users generate only what they need |
| Bloated gem size (tens of MB) | Minimal (KB to few MB) |
| Includes unused locales | Optimized for application |

**Trade-off**: Requires users to generate data, but significant benefits in gem size and flexibility.

---

## ICU4X::DataProvider

A class that provides locale data to formatters.

### Interface

```ruby
module ICU4X
  class DataProvider
    # Load from blob file
    # @param path [Pathname] Path to blob file
    # @param priority [Symbol] Fallback priority (:language or :region)
    # @return [DataProvider]
    # @raise [DataError] If loading fails
    def self.from_blob(path, priority: :language) = ...
  end
end
```

### Usage

```ruby
provider = ICU4X::DataProvider.from_blob(Pathname.new("path/to/data.blob"))

dtf = ICU4X::DateTimeFormat.new(
  ICU4X::Locale.parse("ja-JP"),
  provider: provider,
  date_style: :long
)

dtf.format(Time.now)  # => "2025年12月28日"
```

**Note**: Provider must always be explicitly specified.

---

## Locale Fallback Support

DataProvider includes built-in locale fallback support. When data for a specific locale is not available, it automatically falls back through the locale hierarchy.

### Fallback Chain

```
ja-JP-u-ca-japanese
    ↓ (remove extension)
ja-JP
    ↓ (remove region)
ja
    ↓ (remove language)
und
```

### Fallback Priority

| Priority | Description | Example |
|----------|-------------|---------|
| `:language` (default) | Prioritizes language similarity | `ja-JP` → `ja` → `und` |
| `:region` | Prioritizes region similarity | `ja-JP` → `und-JP` → `und` |

```ruby
# Default (language priority)
provider = ICU4X::DataProvider.from_blob(Pathname.new("path/to/data.blob"))

# Region-priority fallback
provider = ICU4X::DataProvider.from_blob(Pathname.new("path/to/data.blob"), priority: :region)
```

### Important Notes

- Fallback follows the locale hierarchy, not arbitrary language preferences.
  - Example: `ja` will NOT fall back to `en`. It falls back to `und` (undetermined).
- For data to be available via fallback, it must be included when generating the blob file.

---

## ICU4X::DataGenerator

A class for generating locale data blob files.

### Interface

```ruby
module ICU4X
  class DataGenerator
    # Export locale data
    # @param locales [Array<String>] Locales to include
    # @param markers [Symbol, Array<String>] Data markers (:all or specific markers)
    # @param format [Symbol] Output format (:blob)
    # @param output [Pathname] Output path
    # @raise [DataGeneratorError] If generation fails
    def self.export(locales:, markers:, format:, output:) = ...

    # List available markers
    # @return [Array<String>]
    def self.available_markers = ...
  end
end
```

### Usage

```ruby
ICU4X::DataGenerator.export(
  locales: %w[ja en],
  markers: :all,
  format: :blob,
  output: Pathname.new("data/i18n.blob")
)
```

### Markers

Use `DataGenerator.available_markers` to list all available markers, or specify `:all` to include everything.

```ruby
ICU4X::DataGenerator.available_markers
# => ["CalendarJapaneseExtendedV1", "CalendarJapaneseModernV1", "CalendarWeekV1", ...]
```

---

## Notes

- No data is bundled with the gem
- Only blob format is currently supported (fs and baked providers are not implemented)
- Path arguments must be `Pathname` objects, not strings
