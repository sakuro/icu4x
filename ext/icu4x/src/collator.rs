use crate::data_provider::DataProvider;
use crate::helpers;
use icu::collator::Collator as IcuCollator;
use icu::collator::CollatorPreferences;
use icu::collator::options::{CaseLevel, CollatorOptions, Strength};
use icu::collator::preferences::{CollationCaseFirst, CollationNumericOrdering};
use icu_provider::buf::AsDeserializingBufferProvider;
use icu4x_macros::RubySymbol;
use magnus::{
    Error, RHash, RModule, Ruby, TryConvert, Value, function, method, prelude::*,
};
use std::cmp::Ordering;

/// Sensitivity level for collation
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
enum Sensitivity {
    Base,
    Accent,
    Case,
    Variant,
}

/// Case first option
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
enum CaseFirstOption {
    Upper,
    Lower,
}

impl CaseFirstOption {
    fn to_icu_case_first(self) -> CollationCaseFirst {
        match self {
            CaseFirstOption::Upper => CollationCaseFirst::Upper,
            CaseFirstOption::Lower => CollationCaseFirst::Lower,
        }
    }
}

/// Ruby wrapper for ICU4X Collator
#[magnus::wrap(class = "ICU4X::Collator", free_immediately, size)]
pub struct Collator {
    inner: IcuCollator,
    locale_str: String,
    sensitivity: Sensitivity,
    numeric: bool,
    case_first: Option<CaseFirstOption>,
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
unsafe impl Send for Collator {}

impl Collator {
    /// Create a new Collator instance
    ///
    /// # Arguments
    /// * `locale` - A Locale instance
    /// * `provider:` - A DataProvider instance
    /// * `sensitivity:` - :base, :accent, :case, or :variant (default)
    /// * `numeric:` - Whether to use numeric sorting (default: false)
    /// * `case_first:` - :upper, :lower, or nil (default)
    fn new(ruby: &Ruby, args: &[Value]) -> Result<Self, Error> {
        // Parse arguments: (locale, **kwargs)
        let (icu_locale, locale_str) = helpers::extract_locale(ruby, args)?;

        // Get kwargs (optional)
        let kwargs: RHash = if args.len() > 1 {
            TryConvert::try_convert(args[1])?
        } else {
            ruby.hash_new()
        };

        // Resolve provider: use explicit or fall back to default
        let resolved_provider = helpers::resolve_provider(ruby, &kwargs)?;

        // Extract sensitivity option (default: :variant)
        let sensitivity =
            helpers::extract_symbol(ruby, &kwargs, "sensitivity", Sensitivity::from_ruby_symbol)?
                .unwrap_or(Sensitivity::Variant);

        // Extract numeric option (default: false)
        let numeric: bool = kwargs
            .lookup::<_, Option<bool>>(ruby.to_symbol("numeric"))?
            .unwrap_or(false);

        // Extract case_first option (default: nil)
        let case_first = helpers::extract_symbol(
            ruby,
            &kwargs,
            "case_first",
            CaseFirstOption::from_ruby_symbol,
        )?;

        // Get the error exception class
        let error_class = helpers::get_exception_class(ruby, "ICU4X::Error");

        // Get the DataProvider
        let dp: &DataProvider = TryConvert::try_convert(resolved_provider).map_err(|_| {
            Error::new(
                ruby.exception_type_error(),
                "provider must be a DataProvider",
            )
        })?;

        // Build collator options (strength and case_level)
        let mut options = CollatorOptions::default();

        // Set strength based on sensitivity
        options.strength = Some(match sensitivity {
            Sensitivity::Base => Strength::Primary,
            Sensitivity::Accent => Strength::Secondary,
            Sensitivity::Case => Strength::Primary,
            Sensitivity::Variant => Strength::Tertiary,
        });

        // Set case_level for case sensitivity
        if matches!(sensitivity, Sensitivity::Case) {
            options.case_level = Some(CaseLevel::On);
        }

        // Build preferences (numeric and case_first)
        let mut prefs: CollatorPreferences = (&icu_locale).into();

        if numeric {
            prefs.numeric_ordering = Some(CollationNumericOrdering::True);
        }

        if let Some(cf) = case_first {
            prefs.case_first = Some(cf.to_icu_case_first());
        }

        // Create collator
        let collator = IcuCollator::try_new_unstable(&dp.inner.as_deserializing(), prefs, options)
            .map_err(|e| Error::new(error_class, format!("Failed to create Collator: {}", e)))?;

        Ok(Self {
            inner: collator,
            locale_str,
            sensitivity,
            numeric,
            case_first,
        })
    }

    /// Compare two strings
    ///
    /// # Arguments
    /// * `a` - First string
    /// * `b` - Second string
    ///
    /// # Returns
    /// -1 if a < b, 0 if a == b, 1 if a > b
    fn compare(&self, a: Value, b: Value) -> Result<i32, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");

        let str_a: String = TryConvert::try_convert(a).map_err(|_| {
            Error::new(
                ruby.exception_type_error(),
                "first argument must be a String",
            )
        })?;

        let str_b: String = TryConvert::try_convert(b).map_err(|_| {
            Error::new(
                ruby.exception_type_error(),
                "second argument must be a String",
            )
        })?;

        let result = match self.inner.as_borrowed().compare(&str_a, &str_b) {
            Ordering::Less => -1,
            Ordering::Equal => 0,
            Ordering::Greater => 1,
        };

        Ok(result)
    }

    /// Get the resolved options
    ///
    /// # Returns
    /// A hash with :locale, :sensitivity, :numeric, and optionally :case_first
    fn resolved_options(&self) -> Result<RHash, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let hash = ruby.hash_new();
        hash.aset(ruby.to_symbol("locale"), self.locale_str.as_str())?;
        hash.aset(
            ruby.to_symbol("sensitivity"),
            ruby.to_symbol(self.sensitivity.to_symbol_name()),
        )?;
        hash.aset(ruby.to_symbol("numeric"), self.numeric)?;
        if let Some(cf) = self.case_first {
            hash.aset(
                ruby.to_symbol("case_first"),
                ruby.to_symbol(cf.to_symbol_name()),
            )?;
        }
        Ok(hash)
    }
}

pub fn init(ruby: &Ruby, module: &RModule) -> Result<(), Error> {
    let class = module.define_class("Collator", ruby.class_object())?;
    class.define_singleton_method("new", function!(Collator::new, -1))?;
    class.define_method("compare", method!(Collator::compare, 2))?;
    class.define_method("resolved_options", method!(Collator::resolved_options, 0))?;
    Ok(())
}
