## [Unreleased]

## [0.6.1] - 2026-01-02

## [0.6.0] - 2026-01-02

### Added

- **Companion data gems**: `icu4x-data-full`, `icu4x-data-recommended`, `icu4x-data-modern` for bundled locale data
  - Auto-configures default provider on require (e.g., `require "icu4x/data/recommended"`)
- **RakeTask**: `ICU4X::RakeTask` for integrating data generation into build workflows
- **Symbolic locale specifiers**: `DataGenerator.export` accepts `:full`, `:recommended`, `:modern`, `:moderate`, `:basic` symbols
- **Automatic 'und' locale**: `DataGenerator.export` automatically includes the `und` (undetermined) locale for fallback

## [0.5.2] - 2026-01-01

### Fixed

- Fix native extension loader for precompiled gems (#61)

## [0.5.1] - 2026-01-01

### Fixed

- Include `icu4x_macros` crate and Cargo workspace files in source gem (#57)

## [0.5.0] - 2026-01-01

### Added

- **Locale**: BCP 47 (`parse`) and POSIX (`parse_posix`) locale parsing
- **DateTimeFormat**: Date/time formatting with timezone and calendar support
- **NumberFormat**: Decimal, currency, and percent formatting with configurable options
- **PluralRules**: Cardinal and ordinal plural category selection
- **Collator**: Locale-sensitive string comparison with sensitivity and numeric options
- **ListFormat**: Conjunction, disjunction, and unit list formatting
- **RelativeTimeFormat**: Relative time formatting for all time units
- **DisplayNames**: Localized names for languages, regions, scripts, and locales
- **Segmenter**: Text segmentation by grapheme, word, sentence, or line
- **DataProvider**: Blob data loading with automatic locale fallback
- **DataGenerator**: CLDR data export with locale and marker filtering
