use crate::data_provider::DataProvider;
use crate::helpers;
use fixed_decimal::Decimal;
use icu::plurals::{
    PluralCategory, PluralRuleType, PluralRulesPreferences, PluralRulesWithRanges,
};
use icu_provider::buf::AsDeserializingBufferProvider;
use magnus::{
    Error, RArray, RHash, RModule, Ruby, Symbol, TryConvert, Value, function, method, prelude::*,
};

/// Ruby wrapper for ICU4X PluralRules
#[magnus::wrap(class = "ICU4X::PluralRules", free_immediately, size)]
pub struct PluralRules {
    inner: PluralRulesWithRanges<icu::plurals::PluralRules>,
    locale_str: String,
    rule_type: PluralRuleType,
}

// SAFETY: This type is marked as Send to allow Ruby to move it between threads.
//
// Thread safety is guaranteed by Ruby's Global VM Lock (GVL):
// - All Ruby method calls are serialized by the GVL
// - Only one thread can execute Ruby code at a time
// - The underlying ICU4X types are only accessed through Ruby method calls
//
// WARNING: This safety guarantee does NOT hold if:
// - The GVL is released via `rb_thread_call_without_gvl`
// - Using threading libraries that bypass the GVL
//
// In such cases, concurrent access to this type would be unsafe.
unsafe impl Send for PluralRules {}

impl PluralRules {
    /// Create a new PluralRules instance
    ///
    /// # Arguments
    /// * `locale` - A Locale instance
    /// * `provider:` - A DataProvider instance
    /// * `type:` - :cardinal (default) or :ordinal
    fn new(ruby: &Ruby, args: &[Value]) -> Result<Self, Error> {
        // Parse arguments: (locale, **kwargs)
        let (icu_locale, locale_str) = helpers::extract_locale(ruby, args)?;

        // Convert to PluralRulesPreferences
        let prefs: PluralRulesPreferences = (&icu_locale).into();

        // Get kwargs (optional)
        let kwargs: RHash = if args.len() > 1 {
            TryConvert::try_convert(args[1])?
        } else {
            ruby.hash_new()
        };

        // Resolve provider: use explicit or fall back to default
        let resolved_provider = helpers::resolve_provider(ruby, &kwargs)?;

        // Extract type option (default: :cardinal)
        let type_value: Option<Symbol> =
            kwargs.lookup::<_, Option<Symbol>>(ruby.to_symbol("type"))?;
        let cardinal_sym = ruby.to_symbol("cardinal");
        let ordinal_sym = ruby.to_symbol("ordinal");
        let type_sym = type_value.unwrap_or(cardinal_sym);

        let rule_type = if type_sym.equal(cardinal_sym)? {
            PluralRuleType::Cardinal
        } else if type_sym.equal(ordinal_sym)? {
            PluralRuleType::Ordinal
        } else {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "type must be :cardinal or :ordinal",
            ));
        };

        // Get the error exception class
        let error_class = helpers::get_exception_class(ruby, "ICU4X::Error");

        // Get the DataProvider
        let dp: &DataProvider = TryConvert::try_convert(resolved_provider).map_err(|_| {
            Error::new(
                ruby.exception_type_error(),
                "provider must be a DataProvider",
            )
        })?;

        // Create PluralRulesWithRanges from DataProvider
        let rules = match rule_type {
            PluralRuleType::Cardinal => PluralRulesWithRanges::try_new_cardinal_unstable(
                &dp.inner.as_deserializing(),
                prefs,
            ),
            PluralRuleType::Ordinal => PluralRulesWithRanges::try_new_ordinal_unstable(
                &dp.inner.as_deserializing(),
                prefs,
            ),
            _ => PluralRulesWithRanges::try_new_cardinal_unstable(
                &dp.inner.as_deserializing(),
                prefs,
            ),
        }
        .map_err(|e| Error::new(error_class, format!("Failed to create PluralRules: {}", e)))?;

        Ok(Self {
            inner: rules,
            locale_str,
            rule_type,
        })
    }

    /// Determine the plural category for a number
    ///
    /// # Arguments
    /// * `number` - An integer or float
    ///
    /// # Returns
    /// A symbol: :zero, :one, :two, :few, :many, or :other
    fn select(&self, number: Value) -> Result<Symbol, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");

        // Check if it's a Float first (before Integer, since i64::try_convert
        // on Float uses to_int which truncates the decimal part)
        let category = if number.is_kind_of(ruby.class_float()) {
            let f: f64 = TryConvert::try_convert(number)?;
            // For floats, convert to Decimal to preserve fractional digits
            let s = format!("{}", f);
            if let Ok(fd) = s.parse::<Decimal>() {
                self.inner.rules().category_for(&fd)
            } else {
                return Err(Error::new(
                    ruby.exception_arg_error(),
                    format!("Failed to convert {} to Decimal", f),
                ));
            }
        } else if number.is_kind_of(ruby.class_integer()) {
            let n: i64 = TryConvert::try_convert(number)?;
            self.inner.rules().category_for(n as usize)
        } else {
            return Err(Error::new(
                ruby.exception_type_error(),
                "number must be an Integer or Float",
            ));
        };

        Ok(Self::category_to_symbol(&ruby, category))
    }

    /// Determine the plural category for a range of numbers
    ///
    /// # Arguments
    /// * `start` - The start of the range (integer or float)
    /// * `end` - The end of the range (integer or float)
    ///
    /// # Returns
    /// A symbol: :zero, :one, :two, :few, :many, or :other
    fn select_range(&self, start: Value, end: Value) -> Result<Symbol, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");

        let start_decimal = Self::value_to_decimal(&ruby, start, "start")?;
        let end_decimal = Self::value_to_decimal(&ruby, end, "end")?;

        let category = self
            .inner
            .category_for_range(&start_decimal, &end_decimal);

        Ok(Self::category_to_symbol(&ruby, category))
    }

    /// Convert a Ruby Value to a fixed_decimal::Decimal
    fn value_to_decimal(ruby: &Ruby, value: Value, name: &str) -> Result<Decimal, Error> {
        if value.is_kind_of(ruby.class_float()) {
            let f: f64 = TryConvert::try_convert(value)?;
            let s = format!("{}", f);
            s.parse::<Decimal>().map_err(|_| {
                Error::new(
                    ruby.exception_arg_error(),
                    format!("Failed to convert {} ({}) to Decimal", name, f),
                )
            })
        } else if value.is_kind_of(ruby.class_integer()) {
            let n: i64 = TryConvert::try_convert(value)?;
            Ok(Decimal::from(n))
        } else {
            Err(Error::new(
                ruby.exception_type_error(),
                format!("{} must be an Integer or Float", name),
            ))
        }
    }

    /// Get the list of plural categories for this locale
    ///
    /// # Returns
    /// An array of symbols representing available categories
    fn categories(&self) -> RArray {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let array = ruby.ary_new();
        for category in self.inner.rules().categories() {
            let _ = array.push(Self::category_to_symbol(&ruby, category));
        }
        array
    }

    /// Get the resolved options
    ///
    /// # Returns
    /// A hash with :locale and :type keys
    fn resolved_options(&self) -> Result<RHash, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let hash = ruby.hash_new();
        hash.aset(ruby.to_symbol("locale"), self.locale_str.as_str())?;
        let type_sym = match self.rule_type {
            PluralRuleType::Cardinal => ruby.to_symbol("cardinal"),
            PluralRuleType::Ordinal => ruby.to_symbol("ordinal"),
            _ => ruby.to_symbol("cardinal"),
        };
        hash.aset(ruby.to_symbol("type"), type_sym)?;
        Ok(hash)
    }

    /// Convert ICU4X PluralCategory to Ruby Symbol
    fn category_to_symbol(ruby: &Ruby, category: PluralCategory) -> Symbol {
        match category {
            PluralCategory::Zero => ruby.to_symbol("zero"),
            PluralCategory::One => ruby.to_symbol("one"),
            PluralCategory::Two => ruby.to_symbol("two"),
            PluralCategory::Few => ruby.to_symbol("few"),
            PluralCategory::Many => ruby.to_symbol("many"),
            PluralCategory::Other => ruby.to_symbol("other"),
        }
    }
}

pub fn init(ruby: &Ruby, module: &RModule) -> Result<(), Error> {
    let class = module.define_class("PluralRules", ruby.class_object())?;
    class.define_singleton_method("new", function!(PluralRules::new, -1))?;
    class.define_method("select", method!(PluralRules::select, 1))?;
    class.define_method("select_range", method!(PluralRules::select_range, 2))?;
    class.define_method("categories", method!(PluralRules::categories, 0))?;
    class.define_method(
        "resolved_options",
        method!(PluralRules::resolved_options, 0),
    )?;
    Ok(())
}
