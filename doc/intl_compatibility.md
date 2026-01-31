# JavaScript Intl API Compatibility

This document tracks which JavaScript Intl API options are supported in ICU4X Ruby bindings and the implementation feasibility for missing features.

## Legend

- Supported - Currently implemented
- Possible - ICU4X Rust crate supports this feature
- Experimental - Available via ICU4X experimental features
- Planned - ICU4X is actively developing this feature
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

### Missing Options

| Option | Intl Feature | Status |
|--------|-------------|--------|
| `hour_cycle` | 12/24 hour format control | Possible |
| `day_period` | AM/PM display style | Possible |
| Component options | Individual field control (year, month, day, etc.) | Experimental |
| `numbering_system` | Numbering system selection | Possible |
| `format_to_parts` | Get formatted parts array | Possible |

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
| `numbering_system` | Numbering system selection | Possible |
| `format_to_parts` | Get formatted parts array | Possible |

---

## ListFormat

### Supported Options

| Option | Values |
|--------|--------|
| `type` | `:conjunction`, `:disjunction`, `:unit` |
| `style` | `:long`, `:short`, `:narrow` |

### Missing Options

| Option | Intl Feature | Status |
|--------|-------------|--------|
| `format_to_parts` | Get formatted parts array | Possible |

---

## RelativeTimeFormat

### Supported Options

| Option | Values |
|--------|--------|
| `style` | `:long`, `:short`, `:narrow` |
| `numeric` | `:always`, `:auto` |

### Supported Units

`:second`, `:minute`, `:hour`, `:day`, `:week`, `:month`, `:quarter`, `:year`

### Missing Options

| Option | Intl Feature | Status |
|--------|-------------|--------|
| `numbering_system` | Numbering system selection | Possible |
| `format_to_parts` | Get formatted parts array | Possible |

---

## DisplayNames

### Supported Options

| Option | Values |
|--------|--------|
| `type` | `:language`, `:region`, `:script`, `:locale` |
| `style` | `:long`, `:short`, `:narrow` |
| `fallback` | `:code`, `:none` |

### Missing Options

| Option | Intl Feature | Status |
|--------|-------------|--------|
| `type: :currency` | Currency name display | Possible |
| `type: :calendar` | Calendar name display | Possible |
| `type: :date_time_field` | DateTime field names | Possible |
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

### High Priority (Immediately Implementable)

1. **`format_to_parts` method** - High value across all formatters
2. **DisplayNames additional types** - currency, calendar, date_time_field
3. **DateTimeFormat hour_cycle** - Commonly requested option

### Medium Priority (Experimental Features)

4. **DateTimeFormat component options** - Experimental but in demand
5. **numbering_system** - Useful for multilingual support

### Low Priority (Waiting for ICU4X)

6. **NumberFormat extensions** - Waiting for ICU4X #6804 (currency_display, unit, compact, etc.)

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
