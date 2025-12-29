# icu4x

Core functionality of the icu4x gem, providing locale handling, data provider abstraction, and data generation capabilities.

---

## Class Structure

```
ICU4X
├─ Locale
├─ DataProvider
├─ LocaleFallbackProvider
├─ DataGenerator
└─ Error
   ├─ LocaleError
   ├─ DataError
   └─ DataGeneratorError
```

---

## ICU4X::Locale

A class representing locale identifiers. Supports BCP 47 format.

### Interface

```ruby
module ICU4X
  class Locale
    # Parse
    # @param locale_str [String] Locale string in BCP 47 format
    # @return [Locale]
    # @raise [LocaleError] If the format is invalid
    def self.parse(locale_str) = ...

    # Language code
    # @return [String, nil]
    def language = ...

    # Script code
    # @return [String, nil]
    def script = ...

    # Region code
    # @return [String, nil]
    def region = ...

    # String representation
    # @return [String]
    def to_s = ...

    # Equality check
    # @param other [Locale]
    # @return [Boolean]
    def ==(other) = ...
  end
end
```

### Usage Examples

```ruby
loc = ICU4X::Locale.parse("ja-JP")
loc.language  # => "ja"
loc.region    # => "JP"
loc.to_s      # => "ja-JP"

loc2 = ICU4X::Locale.parse("en-Latn-US")
loc2.script   # => "Latn"
```

---

## ICU4X::DataProvider

An abstraction that supplies locale data. See [data_provider.md](./data_provider.md) for details.

### Interface

```ruby
module ICU4X
  class DataProvider
    # Create from blob file
    # @param path [Pathname] Path to the blob file
    # @return [DataProvider]
    # @raise [DataError] On read failure
    def self.from_blob(path) = ...
  end
end
```

---

## ICU4X::LocaleFallbackProvider

A wrapper that adds locale fallback support to DataProvider. When data for a specific locale is not found, it falls back through the locale hierarchy (e.g., `ja-JP` → `ja` → `und`).

### Interface

```ruby
module ICU4X
  class LocaleFallbackProvider
    # Create from DataProvider with fallback support
    # @param provider [DataProvider] A DataProvider instance (will be consumed)
    # @param priority [Symbol] Fallback priority (:language or :region), defaults to :language
    # @return [LocaleFallbackProvider]
    # @raise [ArgumentError] If provider was already consumed
    # @note The original DataProvider cannot be reused after this call
    def self.new(provider, priority: :language) = ...
  end
end
```

### Fallback Priority

| Priority | Fallback Chain Example |
|----------|------------------------|
| `:language` (default) | `ja-JP` → `ja` → `und` |
| `:region` | `ja-JP` → `und-JP` → `und` |

### Usage Examples

```ruby
provider = ICU4X::DataProvider.from_blob(Pathname.new("data/i18n.blob"))

# Default: language priority
fallback_provider = ICU4X::LocaleFallbackProvider.new(provider)

# Or with region priority
provider = ICU4X::DataProvider.from_blob(Pathname.new("data/i18n.blob"))
fallback_provider = ICU4X::LocaleFallbackProvider.new(provider, priority: :region)
```

---

## ICU4X::DataGenerator

Functionality for generating locale data. Wraps the `icu_datagen` crate.

### Interface

```ruby
module ICU4X
  class DataGenerator
    # Generate data
    # @param locales [Array<String>] List of locales
    # @param markers [Symbol, Array<Symbol>] :all or [:datetime, :number, :plurals]
    # @param format [Symbol] :blob
    # @param output [Pathname] Output path
    # @raise [DataGeneratorError] On generation failure
    def self.export(locales:, markers:, format:, output:) = ...
  end
end
```

### Usage Examples

```ruby
ICU4X::DataGenerator.export(
  locales: %w[ja en zh-Hans],
  markers: :all,
  format: :blob,
  output: Pathname.new("data/i18n.blob")
)
```

---

## ICU4X::Error

Error class hierarchy.

```ruby
module ICU4X
  class Error < StandardError; end

  class LocaleError < Error; end
  class DataError < Error; end
  class DataGeneratorError < Error; end
end
```

---

## Rust Extension

Located in `ext/icu4x/`.

### Dependent Crates

```toml
[dependencies]
magnus = "0.8"
icu_locale = "2.1"
icu_provider_blob = "2.1"
icu_provider_source = "2.1"
icu_provider_export = "2.1"
icu_provider_adapters = "2.1"
icu = "2.1"
```

### Rust Module Structure

```
ext/icu4x/src/
├─ lib.rs                      # Entry point, magnus initialization
├─ locale.rs                   # Locale bindings
├─ data_provider.rs            # DataProvider bindings
├─ locale_fallback_provider.rs # LocaleFallbackProvider bindings
└─ data_generator.rs           # DataGenerator bindings
```

---

## File Structure

```
icu4x/
├─ icu4x.gemspec
├─ Gemfile
├─ Rakefile
├─ lib/
│  ├─ icu4x.rb
│  └─ icu4x/
│     └─ version.rb
├─ sig/
│  └─ icu4x.rbs               # RBS type definitions
├─ ext/
│  └─ icu4x/
│     ├─ Cargo.toml
│     ├─ extconf.rb
│     └─ src/
│        ├─ lib.rs
│        ├─ locale.rs
│        ├─ data_provider.rs
│        ├─ locale_fallback_provider.rs
│        └─ data_generator.rs
└─ spec/
   └─ fixtures/               # Test blob (not in git, generated in CI)
```

---

## Related

- [data_provider.md](./data_provider.md)
- [icu4x_ruby_design.md](../icu4x_ruby_design.md) - Sections 2.2, 9
