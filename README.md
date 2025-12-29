# ICU4X

Ruby bindings for [ICU4X](https://github.com/unicode-org/icu4x), providing internationalization functionality.

## Overview

ICU4X is a Unicode library that provides locale-aware formatting and processing. This gem wraps ICU4X via Rust extensions, offering an API similar to JavaScript's Intl.

No locale data is bundled with the gem. Users generate only the data they need, keeping applications lean.

## Features

- **Locale** - BCP 47 and POSIX locale identifier parsing
- **DateTimeFormat** - Locale-aware date/time formatting with timezone support
- **NumberFormat** - Number, currency, and percent formatting
- **PluralRules** - CLDR plural category selection (cardinal/ordinal)
- **DataProvider** - Locale data loading with automatic fallback
- **DataGenerator** - Locale data generation from CLDR

## Requirements

- Ruby 3.2+
- Rust toolchain (for building the native extension)

## Setup

Add to your Gemfile:

```ruby
gem "icu4x"
```

Then generate locale data for your application:

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

# Load locale data
provider = ICU4X::DataProvider.from_blob(Pathname.new("data/i18n.blob"))

# Parse locale (BCP 47 or POSIX format)
locale = ICU4X::Locale.parse("ja-JP")
locale = ICU4X::Locale.parse_posix("ja_JP.UTF-8")  # POSIX format also supported

# Date/time formatting
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
```

See [doc/](doc/) for detailed documentation.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sakuro/icu4x.

## License

MIT License. See [LICENSE](LICENSE.txt) for details.
