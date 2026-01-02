# ICU4X

Ruby bindings for [ICU4X](https://github.com/unicode-org/icu4x), providing internationalization functionality.

## Overview

ICU4X is a Unicode library that provides locale-aware formatting and processing. This gem wraps ICU4X via Rust extensions, offering an API similar to JavaScript's Intl.

No locale data is bundled with the gem. Users generate only the data they need, keeping applications lean.

## Features

- **Locale** - BCP 47 and POSIX locale identifier parsing
- **DateTimeFormat** - Locale-aware date/time formatting with timezone and calendar support
- **NumberFormat** - Number, currency, and percent formatting
- **PluralRules** - CLDR plural category selection (cardinal/ordinal)
- **Collator** - Locale-sensitive string comparison and sorting
- **ListFormat** - Locale-aware list formatting (and, or, unit)
- **RelativeTimeFormat** - Relative time formatting (e.g., "3 days ago")
- **DisplayNames** - Localized names for languages, regions, and scripts
- **Segmenter** - Text segmentation (grapheme, word, sentence, line)
- **DataProvider** - Locale data loading with automatic fallback
- **DataGenerator** - Locale data generation from CLDR

## Requirements

- Ruby 3.2+
- Rust toolchain (only required when building from source; prebuilt binary gems are available for major platforms)

## Setup

Add to your Gemfile:

```ruby
gem "icu4x"
```

Prebuilt binary gems are available for x86_64-linux, aarch64-linux, x86_64-darwin, arm64-darwin, and x64-mingw-ucrt. On these platforms, no Rust toolchain is required.

### Data Preparation

#### Option 1: Use Pre-built Data Gem (Quick Start)

Add a companion data gem for instant setup:

```ruby
gem "icu4x"
gem "icu4x-data-recommended"  # 164 locales, ~24MB
```

```ruby
require "icu4x"
require "icu4x/data/recommended"  # Auto-configures default provider
```

Available data gems:
- `icu4x-data-full` - All CLDR locales (700+)
- `icu4x-data-recommended` - Recommended locales (164)
- `icu4x-data-modern` - Modern coverage locales (103)

#### Option 2: Generate Custom Data

For fine-grained control, generate only the locales you need:

```ruby
require "icu4x"

ICU4X::DataGenerator.export(
  locales: %w[en ja],
  markers: :all,
  format: :blob,
  output: Pathname.new("data/i18n.blob")
)
```

## Usage

```ruby
require "icu4x"

# Option 1: Configure default provider (recommended)
ICU4X.configure do |config|
  config.data_path = Pathname.new("data/i18n.blob")
end
# Or set ICU4X_DATA_PATH environment variable

# Option 2: Load provider explicitly
provider = ICU4X::DataProvider.from_blob(Pathname.new("data/i18n.blob"))

# Parse locale (BCP 47 or POSIX format)
locale = ICU4X::Locale.parse("ja-JP")
locale = ICU4X::Locale.parse_posix("ja_JP.UTF-8")  # POSIX format also supported

# Date/time formatting (provider: can be omitted if default is configured)
dtf = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long)
dtf.format(Time.now)
# => "2025年12月30日"

# Number formatting
nf = ICU4X::NumberFormat.new(locale, provider:, style: :currency, currency: "JPY")
nf.format(1_234_567)
# => "￥1,234,567"

# Plural rules
pr = ICU4X::PluralRules.new(ICU4X::Locale.parse("en"), provider:)
pr.select(1)   # => :one
pr.select(2)   # => :other

# Collation (sorting)
collator = ICU4X::Collator.new(locale, provider:)
%w[メロン アップル なし].sort { |a, b| collator.compare(a, b) }
# => ["アップル", "なし", "メロン"]

# List formatting
lf = ICU4X::ListFormat.new(locale, provider:, type: :conjunction)
lf.format(%w[Apple Banana Cherry])
# => "Apple、Banana、Cherry"

# Relative time formatting
rtf = ICU4X::RelativeTimeFormat.new(locale, provider:)
rtf.format(-3, :day)
# => "3日前"

# Display names
dn = ICU4X::DisplayNames.new(locale, provider:, type: :language)
dn.of("en")
# => "英語"

# Text segmentation
segmenter = ICU4X::Segmenter.new(granularity: :word, provider:)
segmenter.segment("Hello, world!").map(&:segment)
# => ["Hello", ",", " ", "world", "!"]
```

See [doc/](doc/) for detailed documentation.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sakuro/icu4x.

## License

MIT License. See [LICENSE](LICENSE.txt) for details.
