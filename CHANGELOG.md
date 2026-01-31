## [Unreleased]

### Added

- `ICU4X::RelativeTimeFormat#format_to_parts` method for breaking down formatted output into typed parts (#117)
- `ICU4X::ListFormat#format_to_parts` method for breaking down formatted output into typed parts (#116)
- `ICU4X::DateTimeFormat#format_to_parts` method for breaking down formatted output into typed parts (#114)
- `ICU4X::NumberFormat#format_to_parts` method for breaking down formatted output into typed parts (#115)
- `ICU4X::FormattedPart` data class for representing formatted parts (#113)
- `ICU4X::PluralRules#select_range` method for plural category selection on number ranges (#106)
- Allow data gems to be required by gem name (#104)
- `ICU4X::Locale.parse_bcp47` method for explicit BCP 47 parsing; `parse` is now an alias (#108)

## [0.8.1] - 2026-01-12

### Added

- Add Ruby 4.0 prebuilt binary support (#101)

## [0.8.0] - 2026-01-10

### Added

- `ICU4X::Locale#maximize!` and `#maximize` methods to expand locale using Likely Subtags algorithm (UTS #35)
- `ICU4X::Locale#minimize!` and `#minimize` methods to remove redundant subtags

## [0.7.0] - 2026-01-09

### Added

- `DateTimeFormat#format` now accepts any object responding to `#to_time` (e.g., `Date`, `DateTime`)

## [0.6.2] - 2026-01-02

### Fixed

- Fix incorrect `Segment#text` → `#segment` in README example
- Improve README Setup section (mention prebuilt binary gems, add Data Preparation heading)
- Replace YARD `+...+` syntax with markdown backticks for consistency

## [0.6.1] - 2026-01-02

### Changed

- Re-release to publish companion data gems with Trusted Publisher configuration

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
