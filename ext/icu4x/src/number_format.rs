use crate::data_provider::DataProvider;
use crate::locale::Locale;
use fixed_decimal::Decimal;
use icu::decimal::{DecimalFormatter, DecimalFormatterPreferences};
use icu::decimal::options::{DecimalFormatterOptions, GroupingStrategy};
use icu_provider::buf::AsDeserializingBufferProvider;
use magnus::{
    function, method, prelude::*, Error, ExceptionClass, RHash, RModule, Ruby, TryConvert, Value,
};

/// Ruby wrapper for ICU4X DecimalFormatter
#[magnus::wrap(class = "ICU4X::NumberFormat", free_immediately, size)]
pub struct NumberFormat {
    inner: DecimalFormatter,
    locale_str: String,
    use_grouping: bool,
}

// SAFETY: Ruby's GVL protects access to this type.
unsafe impl Send for NumberFormat {}

impl NumberFormat {
    /// Create a new NumberFormat instance
    ///
    /// # Arguments
    /// * `locale` - A Locale instance
    /// * `provider:` - A DataProvider instance
    /// * `use_grouping:` - Whether to use grouping separators (default: true)
    fn new(ruby: &Ruby, args: &[Value]) -> Result<Self, Error> {
        // Parse arguments: (locale, **kwargs)
        if args.is_empty() {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "wrong number of arguments (given 0, expected 1+)",
            ));
        }

        // Get the locale
        let locale: &Locale = TryConvert::try_convert(args[0])?;
        let locale_ref = locale.inner.borrow();
        let locale_str = locale_ref.to_string();
        let icu_locale = locale_ref.clone();
        drop(locale_ref);

        // Convert to DecimalFormatterPreferences
        let prefs: DecimalFormatterPreferences = (&icu_locale).into();

        // Get kwargs
        let kwargs: RHash = if args.len() > 1 {
            TryConvert::try_convert(args[1])?
        } else {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "missing keyword: :provider",
            ));
        };

        // Extract provider (required)
        let provider_value: Value = kwargs
            .lookup::<_, Option<Value>>(ruby.to_symbol("provider"))?
            .ok_or_else(|| Error::new(ruby.exception_arg_error(), "missing keyword: :provider"))?;

        // Extract use_grouping option (default: true)
        let use_grouping: bool = kwargs
            .lookup::<_, Option<bool>>(ruby.to_symbol("use_grouping"))?
            .unwrap_or(true);

        // Get the error exception class
        let error_class: ExceptionClass = ruby
            .eval("ICU4X::Error")
            .unwrap_or_else(|_| ruby.exception_runtime_error());

        // Get the DataProvider
        let dp: &DataProvider = TryConvert::try_convert(provider_value).map_err(|_| {
            Error::new(
                ruby.exception_type_error(),
                "provider must be a DataProvider",
            )
        })?;

        // Build options
        let mut options = DecimalFormatterOptions::default();
        options.grouping_strategy = Some(if use_grouping {
            GroupingStrategy::Auto
        } else {
            GroupingStrategy::Never
        });

        // Create DecimalFormatter
        let formatter = DecimalFormatter::try_new_unstable(
            &dp.inner.as_deserializing(),
            prefs,
            options,
        )
        .map_err(|e| Error::new(error_class, format!("Failed to create NumberFormat: {}", e)))?;

        Ok(Self {
            inner: formatter,
            locale_str,
            use_grouping,
        })
    }

    /// Format a number
    ///
    /// # Arguments
    /// * `number` - An integer or float
    ///
    /// # Returns
    /// A formatted string
    fn format(&self, number: Value) -> Result<String, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");

        let decimal = Self::convert_to_decimal(&ruby, number)?;
        let formatted = self.inner.format(&decimal);
        Ok(formatted.to_string())
    }

    /// Convert Ruby number to Decimal
    fn convert_to_decimal(ruby: &Ruby, number: Value) -> Result<Decimal, Error> {
        if number.is_kind_of(ruby.class_float()) {
            let f: f64 = TryConvert::try_convert(number)?;
            let s = format!("{}", f);
            s.parse::<Decimal>().map_err(|e| {
                Error::new(
                    ruby.exception_arg_error(),
                    format!("Failed to convert {} to Decimal: {}", f, e),
                )
            })
        } else if number.is_kind_of(ruby.class_integer()) {
            let n: i64 = TryConvert::try_convert(number)?;
            Ok(Decimal::from(n))
        } else {
            Err(Error::new(
                ruby.exception_type_error(),
                "number must be an Integer or Float",
            ))
        }
    }

    /// Get the resolved options
    ///
    /// # Returns
    /// A hash with :locale, :style, and :use_grouping keys
    fn resolved_options(&self) -> Result<RHash, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let hash = ruby.hash_new();
        hash.aset(ruby.to_symbol("locale"), self.locale_str.as_str())?;
        hash.aset(ruby.to_symbol("style"), ruby.to_symbol("decimal"))?;
        hash.aset(ruby.to_symbol("use_grouping"), self.use_grouping)?;
        Ok(hash)
    }
}

pub fn init(ruby: &Ruby, module: &RModule) -> Result<(), Error> {
    let class = module.define_class("NumberFormat", ruby.class_object())?;
    class.define_singleton_method("new", function!(NumberFormat::new, -1))?;
    class.define_method("format", method!(NumberFormat::format, 1))?;
    class.define_method("resolved_options", method!(NumberFormat::resolved_options, 0))?;
    Ok(())
}
