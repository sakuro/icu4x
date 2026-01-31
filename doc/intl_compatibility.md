# JavaScript Intl API Compatibility

This document tracks which JavaScript Intl API options are supported in ICU4X Ruby bindings and the implementation feasibility for missing features.

## Legend

- Supported - Currently implemented
- Possible - ICU4X Rust crate supports this feature
- Experimental - Available via ICU4X experimental features
- Planned - ICU4X is actively developing this feature
- Blocked - Feature not available in ICU4X
- Not Planned - Different design approach in ICU4X

---

## DateTimeFormat

### Supported Options

| Option | Values |
|--------|--------|
| `date_style` | `:full`, `:long`, `:medium`, `:short` |
| `time_style` | `:full`, `:long`, `:medium`, `:short` |
| `time_zone` | IANA timezone name |
| `calendar` | `:gregory`, `:japanese`, `:buddhist`, etc. |
| `hour_cycle` | `:h11`, `:h12`, `:h23` |

### Supported Methods

- `format(time)` - Format a time value
- `format_to_parts(time)` - Get formatted parts array

### Missing Options

| Option | Intl Feature | Status |
|--------|-------------|--------|
| `day_period` | AM/PM display style | Possible |
| Component options | Individual field control (year, month, day, etc.) | Experimental |

### Numbering System

Numbering system is supported via BCP 47 locale extension (`-u-nu-xxx`):

```ruby
locale = ICU4X::Locale.parse("ja-JP-u-nu-hanidec")
formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long)
formatter.format(Time.utc(2025, 12, 28))  # => "二〇二五年一二月二八日"
```

---

## NumberFormat

### Supported Options

| Option | Values |
|--------|--------|
| `style` | `:decimal`, `:percent`, `:currency` |
| `currency` | ISO 4217 currency code |
| `use_grouping` | `true`, `false` |
| `minimum_integer_digits` | Integer |
| `minimum_fraction_digits` | Integer |
| `maximum_fraction_digits` | Integer |
| `rounding_mode` | `:ceil`, `:floor`, `:expand`, `:trunc`, `:half_ceil`, `:half_floor`, `:half_expand`, `:half_trunc`, `:half_even` |

### Supported Methods

- `format(number)` - Format a number value
- `format_to_parts(number)` - Get formatted parts array

### Missing Options

| Option | Intl Feature | Status |
|--------|-------------|--------|
| `currency_display` | symbol/code/name display | Planned (ICU4X #6804) |
| `currency_sign` | standard/accounting format | Planned |
| `unit` / `unit_display` | Unit formatting | Planned |
| `notation` | scientific/engineering/compact | Planned |
| `compact_display` | short/long compact format | Planned |
| `sign_display` | always/never/exceptZero | Planned |
| `minimum_significant_digits` | Significant digits control | Possible |
| `maximum_significant_digits` | Significant digits control | Possible |

### Numbering System

Numbering system is supported via BCP 47 locale extension (`-u-nu-xxx`):

```ruby
locale = ICU4X::Locale.parse("ja-JP-u-nu-hanidec")
formatter = ICU4X::NumberFormat.new(locale, provider:)
formatter.format(1234)  # => "一,二三四"
```

---

## ListFormat

### Supported Options

| Option | Values |
|--------|--------|
| `type` | `:conjunction`, `:disjunction`, `:unit` |
| `style` | `:long`, `:short`, `:narrow` |

### Supported Methods

- `format(list)` - Format an array of strings
- `format_to_parts(list)` - Get formatted parts array

---

## RelativeTimeFormat

### Supported Options

| Option | Values |
|--------|--------|
| `style` | `:long`, `:short`, `:narrow` |
| `numeric` | `:always`, `:auto` |

### Supported Units

`:second`, `:minute`, `:hour`, `:day`, `:week`, `:month`, `:quarter`, `:year`

### Supported Methods

- `format(value, unit)` - Format a relative time value
- `format_to_parts(value, unit)` - Get formatted parts array

### Numbering System

Numbering system is supported via BCP 47 locale extension (`-u-nu-xxx`):

```ruby
locale = ICU4X::Locale.parse("ja-u-nu-hanidec")
rtf = ICU4X::RelativeTimeFormat.new(locale, provider:)
rtf.format(-3, :day)  # => "三 日前"
```

---

## DisplayNames

### Supported Options

| Option | Values |
|--------|--------|
| `type` | `:language`, `:region`, `:script`, `:locale` |
| `style` | `:long`, `:short`, `:narrow` |
| `fallback` | `:code`, `:none` |

### Supported Methods

- `of(code)` - Get display name for a code

### Missing Options

| Option | Intl Feature | Status |
|--------|-------------|--------|
| `type: :currency` | Currency name display | Blocked (not in ICU4X displaynames) |
| `type: :calendar` | Calendar name display | Blocked (not in ICU4X displaynames) |
| `type: :date_time_field` | DateTime field names | Blocked (not in ICU4X displaynames) |
| `language_display` | dialect/standard mode | Possible |

---

## PluralRules

### Supported Options

| Option | Values |
|--------|--------|
| `type` | `:cardinal`, `:ordinal` |

### Supported Methods

- `select(number)` - Get plural category
- `select_range(start, end)` - Get plural category for range
- `categories` - Get available categories

### Missing Options

| Option | Intl Feature | Status |
|--------|-------------|--------|
| Digit options | Control plural selection based on digit display | Possible |

---

## Implementation Priority

### Medium Priority (Experimental Features)

1. **DateTimeFormat component options** - Experimental but in demand

### Low Priority (Waiting for ICU4X)

2. **NumberFormat extensions** - Waiting for ICU4X #6804 (currency_display, unit, compact, etc.)
3. **DisplayNames additional types** - Blocked (currency, calendar, date_time_field not in ICU4X displaynames module)

---

## Notes

- `locale_matcher` option from Intl is not applicable; ICU4X uses DataProvider fallback mechanism instead
- ICU4X Ruby's `rounding_mode` actually has more options (9 modes) than JavaScript Intl
- NumberFormat advanced features are being developed in ICU4X 2.x (Priority P2)

## References

- [ICU4X HourCycle](https://unicode-org.github.io/icu4x/rustdoc/icu/datetime/options/preferences/enum.HourCycle.html)
- [ICU4X Components API](https://docs.rs/icu/latest/icu/datetime/options/components/index.html)
- [ICU4X #6804 - Measurement Units & Currency](https://github.com/unicode-org/icu4x/issues/6804)
- [MDN Intl](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl)
