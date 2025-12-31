# DisplayNames

Locale-aware display names for languages, regions, scripts, and locales. Equivalent to JavaScript's Intl.DisplayNames.

---

## Class Structure

```
ICU4X
└─ DisplayNames
```

---

## ICU4X::DisplayNames

A class for retrieving display names of language, region, script, and locale identifiers.

### Interface

```ruby
module ICU4X
  class DisplayNames
    # Constructor
    # @param locale [Locale] The locale for display names
    # @param provider [DataProvider] Data provider
    # @param type [Symbol] :language, :region, :script, :locale
    # @param style [Symbol] :long (default), :short, :narrow
    # @param fallback [Symbol] :code (default), :none
    # @raise [ArgumentError] If type, style, or fallback is invalid
    # @raise [Error] If data loading fails
    def initialize(locale, provider:, type:, style: :long, fallback: :code) = ...

    # Get display name for a code
    # @param code [String] Language/region/script code, or locale string
    # @return [String, nil] Display name, or nil when fallback: :none and not found
    def of(code) = ...

    # Get resolved options
    # @return [Hash]
    def resolved_options = ...
  end
end
```

---

## type Option

Required option specifying the type of display name to retrieve.

| Value | Description | Example Code | Example Output (ja) |
|-------|-------------|--------------|---------------------|
| `:language` | Language name | "en" | "英語" |
| `:region` | Region name | "US" | "アメリカ合衆国" |
| `:script` | Script name | "Latn" | "ラテン文字" |
| `:locale` | Full locale name | "en-US" | "アメリカ英語" |

---

## style Option

Controls the length of the display name.

| Value | Description |
|-------|-------------|
| `:long` | Full name (default) |
| `:short` | Abbreviated |
| `:narrow` | Minimal |

---

## fallback Option

Controls behavior when a display name is not found.

| Value | Description | Behavior for unknown code |
|-------|-------------|---------------------------|
| `:code` | Return code itself (default) | "xyz" → "xyz" |
| `:none` | Return nil | "xyz" → nil |

---

## Usage Examples

### Language Names

```ruby
provider = ICU4X::DataProvider.from_blob(Pathname.new("data/i18n.blob"))
locale = ICU4X::Locale.parse("ja")

dn = ICU4X::DisplayNames.new(locale, provider: provider, type: :language)

dn.of("en")  # => "英語"
dn.of("ja")  # => "日本語"
dn.of("de")  # => "ドイツ語"
```

### Region Names

```ruby
dn = ICU4X::DisplayNames.new(locale, provider: provider, type: :region)

dn.of("US")  # => "アメリカ合衆国"
dn.of("JP")  # => "日本"
dn.of("GB")  # => "イギリス"
```

### Script Names

```ruby
dn = ICU4X::DisplayNames.new(locale, provider: provider, type: :script)

dn.of("Latn")  # => "ラテン文字"
dn.of("Hant")  # => "繁体字"
dn.of("Cyrl")  # => "キリル文字"
```

### Locale Names

```ruby
dn = ICU4X::DisplayNames.new(locale, provider: provider, type: :locale)

dn.of("en-US")     # => "アメリカ英語"
dn.of("zh-Hant")   # => "標準中国語 (繁体字)"
dn.of("pt-BR")     # => "ポルトガル語 (ブラジル)"
```

### Fallback Behavior

```ruby
# Default: :code
dn = ICU4X::DisplayNames.new(locale, provider: provider, type: :language)
dn.of("xyz")  # => "xyz" (returns code when not found)

# With :none
dn = ICU4X::DisplayNames.new(locale, provider: provider, type: :language, fallback: :none)
dn.of("xyz")  # => nil
```

### Different Locales

```ruby
# English locale
en_locale = ICU4X::Locale.parse("en")
dn_en = ICU4X::DisplayNames.new(en_locale, provider: provider, type: :language)

dn_en.of("ja")  # => "Japanese"
dn_en.of("en")  # => "English"
```

---

## Notes

- Each type requires different data markers in the blob
- The returned display names follow CLDR conventions
- Uses ICU4X experimental displaynames module
