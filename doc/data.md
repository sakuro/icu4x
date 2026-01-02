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

## Companion Data Gems

For convenience, pre-generated data gems are available as an alternative to self-generation:

| Gem | Locales | Description |
|-----|---------|-------------|
| `icu4x-data-full` | 700+ | All CLDR locales |
| `icu4x-data-recommended` | 164 | Recommended locales (basic + moderate + modern coverage) |
| `icu4x-data-modern` | 103 | Modern coverage locales |

### Usage

```ruby
# Gemfile
gem "icu4x"
gem "icu4x-data-recommended"
```

```ruby
require "icu4x"
require "icu4x/data/recommended"  # Auto-configures default provider

locale = ICU4X::Locale.parse("ja-JP")
dtf = ICU4X::DateTimeFormat.new(locale, date_style: :long)
dtf.format(Time.now)  # => "2025年12月28日"
```

### How It Works

When you require a data gem (e.g., `icu4x/data/recommended`), it automatically calls `ICU4X.configure` to set the `data_path` to the bundled blob file. No manual configuration is needed.

### Choosing a Data Gem

- **`icu4x-data-full`**: Use when you need support for all possible locales
- **`icu4x-data-recommended`**: Good default choice for most applications
- **`icu4x-data-modern`**: Smaller footprint when you only need major languages

For fine-grained control over included locales, generate your own data using `ICU4X::DataGenerator`.

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

---

## Default Provider

Instead of passing `provider:` to every formatter, you can configure a default provider that will be used automatically when `provider:` is omitted.

### Configuration Methods

There are two ways to configure the default provider:

#### 1. Programmatic Configuration

Use `ICU4X.configure` to set the data path:

```ruby
ICU4X.configure do |config|
  config.data_path = Pathname.new("data/i18n.blob")
end
```

#### 2. Environment Variable

Set the `ICU4X_DATA_PATH` environment variable:

```bash
export ICU4X_DATA_PATH=/path/to/data.blob
```

### Priority

When both are set, **programmatic configuration takes precedence** over the environment variable:

1. `config.data_path` (highest priority)
2. `ENV["ICU4X_DATA_PATH"]`

### Usage

Once configured, formatters will use the default provider automatically:

```ruby
# Configure once at application startup
ICU4X.configure do |config|
  config.data_path = Pathname.new("data/i18n.blob")
end

# Create formatters without explicit provider
locale = ICU4X::Locale.parse("ja-JP")
dtf = ICU4X::DateTimeFormat.new(locale, date_style: :long)
nf = ICU4X::NumberFormat.new(locale, style: :currency, currency: "JPY")
```

### Accessing the Default Provider

You can access the default provider directly via `ICU4X.default_provider`:

```ruby
ICU4X.default_provider  # => DataProvider instance or nil
```

The default provider is:
- **Lazy-loaded**: Created on first access, not at configuration time
- **Cached**: The same instance is reused for all formatters
- **Thread-safe**: Safe to use in multi-threaded applications

### Resetting the Default Provider

For testing purposes, you can reset the cached default provider:

```ruby
ICU4X.reset_default_provider!
```

This clears the cached provider, allowing configuration changes to take effect.

### Notes

- If no default provider is configured and `provider:` is omitted, an `ArgumentError` is raised
- You can always override the default by passing `provider:` explicitly
- Path must be a `Pathname` object when using `config.data_path`

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
- When specifying locales, ancestor locales (including `und`) are automatically included via `with_descendants`.

---

## ICU4X::DataGenerator

A class for generating locale data blob files.

### Interface

```ruby
module ICU4X
  class DataGenerator
    # Export locale data
    # @param locales [Symbol, Array<String>] Locale specification:
    #   - :full - all CLDR locales (700+)
    #   - :recommended - basic + moderate + modern coverage (164)
    #   - :modern - modern coverage only (103)
    #   - :moderate - moderate coverage only
    #   - :basic - basic coverage only
    #   - Array<String> - explicit list of locale identifiers
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
# Using explicit locale list
ICU4X::DataGenerator.export(
  locales: %w[ja en],
  markers: :all,
  format: :blob,
  output: Pathname.new("data/i18n.blob")
)

# Using symbolic locale specifier
ICU4X::DataGenerator.export(
  locales: :modern,
  markers: :all,
  format: :blob,
  output: Pathname.new("data/modern.blob")
)
```

### Markers

Use `DataGenerator.available_markers` to list all available markers, or specify `:all` to include everything.

```ruby
ICU4X::DataGenerator.available_markers
# => ["CalendarJapaneseExtendedV1", "CalendarJapaneseModernV1", "CalendarWeekV1", ...]
```

---

## Rake Task

A Rake task for generating data blobs as part of your build workflow.

### Setup

```ruby
# Rakefile
require "icu4x/rake_task"

ICU4X::RakeTask.new do |t|
  t.output = "data/icu4x.postcard"
end
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `locales` | `:recommended` | Locale specifier or array of locale strings |
| `markers` | `:all` | Data markers to include |
| `output` | (required) | Output path relative to Rakefile |

### Task Name

Default task name is `icu4x:data:generate`. Customize by passing a name to the constructor:

```ruby
ICU4X::RakeTask.new("myapp:generate_data") do |t|
  t.output = "data/icu4x.postcard"
end
```

### Usage

```bash
rake icu4x:data:generate  # Generate (skips if file exists)
rake clobber              # Remove generated file
```

### Behavior

- Implemented as a `file` task: generation is skipped if output file already exists
- Output file is automatically added to `CLOBBER` for cleanup

---

## Notes

- No data is bundled with the gem
- Only blob format is currently supported (fs and baked providers are not implemented)
- Path arguments must be `Pathname` objects, not strings
