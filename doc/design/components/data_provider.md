# DataProvider

## Overview

DataProvider is a component that abstracts "where" and "in what format" locale data required by ICU4X is supplied. Formatters (DateTimeFormat, NumberFormat, PluralRules) depend only on DataProvider and are unaware of the data source.

---

## Role in ICU4X

ICU4X is a library that provides internationalization functionality, with a design philosophy of **separating code from data**.

```
┌─────────────────────────────────────────────────────┐
│  Formatters (DateTimeFormat, NumberFormat, etc.)    │
│  └─ Requires locale-specific formatting             │
└──────────────────────┬──────────────────────────────┘
                       │ Data request
                       ▼
┌─────────────────────────────────────────────────────┐
│  LocaleFallbackProvider (optional wrapper)          │
│  └─ Provides locale fallback (ja-JP → ja → und)     │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│  DataProvider (abstraction layer)                   │
│  └─ Abstracts "what" and "where" to retrieve        │
└──────────────────────┬──────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
   ┌─────────┐   ┌─────────┐   ┌─────────┐
   │  Blob   │   │   FS    │   │ Baked   │
   │ Provider│   │ Provider│   │ Provider│
   └────┬────┘   └────┬────┘   └────┬────┘
        ▼              ▼              ▼
   .blob file     Directory      Compile-time
   (Postcard)     structure      embedding
```

---

## Data Structure (Conceptual)

```
DataKey        : What data (datetime / number / plurals, etc.)
DataRequest    : Request parameters like locale / calendar
DataResponse   : Actual data
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

## Provider Types

| Type | Content | Adoption in This Design |
|------|---------|------------------------|
| blob | Single file data (Postcard format) | **Initially adopted** |
| fs | Directory loading | Future |
| baked | Compile-time embedding | Not adopted |

**Note**: No data is bundled with the gem. Generate as needed for testing, development, and production.

---

## Ruby API

### Loading from blob file

```ruby
provider = ICU4X::DataProvider.from_blob(Pathname.new("path/to/data.blob"))

dtf = ICU4X::DateTimeFormat.new(
  ICU4X::Locale.parse("ja-JP"),
  provider: provider,
  date_style: :long
)

dtf.format(Time.now)  # => "2025年12月28日"
```

**Note**: Provider must always be explicitly specified. For locale fallback support, wrap with `LocaleFallbackProvider`.

---

## Locale Fallback Support

When data for a specific locale is not available, ICU4X can fall back through the locale hierarchy. This is achieved by wrapping `DataProvider` with `LocaleFallbackProvider`.

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

### Usage

```ruby
provider = ICU4X::DataProvider.from_blob(Pathname.new("path/to/data.blob"))

# Wrap with fallback support
fallback_provider = ICU4X::LocaleFallbackProvider.new(provider)

# Now formatters will automatically fall back through the locale hierarchy
dtf = ICU4X::DateTimeFormat.new(
  ICU4X::Locale.parse("ja-JP"),
  provider: fallback_provider,
  date_style: :long
)
```

### Fallback Priority

| Priority | Description | Example |
|----------|-------------|---------|
| `:language` (default) | Prioritizes language similarity | `ja-JP` → `ja` → `und` |
| `:region` | Prioritizes region similarity | `ja-JP` → `und-JP` → `und` |

```ruby
# Region-priority fallback
fallback_provider = ICU4X::LocaleFallbackProvider.new(provider, priority: :region)
```

### Important Notes

- `LocaleFallbackProvider.new` **consumes** the `DataProvider`. The original provider cannot be reused.
- Fallback follows the locale hierarchy, not arbitrary language preferences.
  - Example: `ja` will NOT fall back to `en`. It falls back to `und` (undetermined).
- For data to be available via fallback, it must be included when generating the blob file.

---

## Data Supply Method

**User-generated data approach** is adopted:

1. Users generate data using `ICU4X::DataGenerator` API
2. Place generated blob file in application
3. Load at runtime with `DataProvider.from_blob`

### Data Generation Examples

```ruby
ICU4X::DataGenerator.export(
  locales: %w[ja en],
  markers: :all,
  format: :blob,
  output: Pathname.new("data/i18n.blob")
)
```

```bash
# CLI (Rust version, for gem development)
icu4x-datagen --locales ja,en --markers all --format blob --output data/i18n.blob
```

---

## Design Rationale

| Traditional Approach | This Design |
|---------------------|-------------|
| Bundle all locale data with gem | Users generate only what they need |
| Bloated gem size (tens of MB) | Minimal (KB to few MB) |
| Includes unused locales | Optimized for application |

**Trade-off**: Requires users to generate data, but significant benefits in gem size and flexibility.

---

## About Test Data

No data is bundled with the gem. Data generation is required before running tests:

```bash
# For gem development: Use Rust's icu4x-datagen command
$ icu4x-datagen --locales en,ja,ru,ar --markers all --format blob --output spec/fixtures/test.blob
```

- **Location**: `spec/fixtures/` directory
- **Git management**: Excluded via `.gitignore`
- **CI**: Generate before each test run

---

## Related

- [icu4x_ruby_design.md](../icu4x_ruby_design.md) - Sections 4, 9
- [ICU4X Data Management](https://docs.rs/icu_provider/latest/icu_provider/) - Rust documentation
