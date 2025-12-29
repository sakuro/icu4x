# Development Guide

## Directory Structure

```
icu4x/
├─ lib/           # Ruby code
├─ ext/icu4x/     # Rust extension
├─ sig/           # RBS type definitions
├─ spec/          # Tests
└─ doc/           # Documentation
```

## Class Structure

```
ICU4X
├─ Locale
├─ DataProvider
├─ DataGenerator
├─ DateTimeFormat
├─ NumberFormat
├─ PluralRules
└─ Error
   ├─ LocaleError
   ├─ DataError
   └─ DataGeneratorError
```

## Running Tests

```bash
bundle exec rake spec
```

Test data (`spec/fixtures/test-data.postcard`) is automatically generated as a dependency of the `spec` task. Included locales: en, ja, de, ru, ar, und.

## Type Checking

RBS type definitions are in `sig/icu4x.rbs`.

```bash
bundle exec steep check
```

## Documentation

- [locale.md](doc/locale.md) - Locale and error classes
- [data.md](doc/data.md) - DataProvider and DataGenerator
- [datetime.md](doc/datetime.md) - DateTimeFormat
- [number.md](doc/number.md) - NumberFormat
- [plurals.md](doc/plurals.md) - PluralRules
