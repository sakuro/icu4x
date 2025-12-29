use crate::data_provider::DataProvider;
use crate::locale::Locale;
use fixed_decimal::Decimal;
use icu::decimal::options::{DecimalFormatterOptions, GroupingStrategy};
use icu::decimal::{DecimalFormatter, DecimalFormatterPreferences};
use icu::experimental::dimension::currency::formatter::{
    CurrencyFormatter, CurrencyFormatterPreferences,
};
use icu::experimental::dimension::currency::options::CurrencyFormatterOptions;
use icu::experimental::dimension::currency::CurrencyCode;
use icu::experimental::dimension::percent::formatter::{
    PercentFormatter, PercentFormatterPreferences,
};
use icu::experimental::dimension::percent::options::PercentFormatterOptions;
use icu_provider::buf::AsDeserializingBufferProvider;
use magnus::{
    function, method, prelude::*, Error, ExceptionClass, RHash, RModule, Ruby, Symbol, TryConvert,
    Value,
};
use tinystr::TinyAsciiStr;

/// The style of number formatting
#[derive(Clone, Copy, PartialEq, Eq)]
enum Style {
    Decimal,
    Percent,
    Currency,
}

/// Internal formatter storage
enum FormatterKind {
    Decimal(DecimalFormatter),
    Percent(PercentFormatter<DecimalFormatter>),
    Currency(CurrencyFormatter, CurrencyCode),
}

/// Ruby wrapper for ICU4X number formatters
#[magnus::wrap(class = "ICU4X::NumberFormat", free_immediately, size)]
pub struct NumberFormat {
    inner: FormatterKind,
    locale_str: String,
    style: Style,
    use_grouping: bool,
    currency_code: Option<String>,
}

// SAFETY: Ruby's GVL protects access to this type.
unsafe impl Send for NumberFormat {}

impl NumberFormat {
    /// Create a new NumberFormat instance
    ///
    /// # Arguments
    /// * `locale` - A Locale instance
    /// * `provider:` - A DataProvider instance
    /// * `style:` - :decimal (default), :percent, or :currency
    /// * `currency:` - Currency code (required for style: :currency)
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

        // Extract style option (default: :decimal)
        let style_value: Option<Symbol> =
            kwargs.lookup::<_, Option<Symbol>>(ruby.to_symbol("style"))?;
        let decimal_sym = ruby.to_symbol("decimal");
        let percent_sym = ruby.to_symbol("percent");
        let currency_sym = ruby.to_symbol("currency");
        let style_sym = style_value.unwrap_or(decimal_sym);

        let style = if style_sym.equal(decimal_sym)? {
            Style::Decimal
        } else if style_sym.equal(percent_sym)? {
            Style::Percent
        } else if style_sym.equal(currency_sym)? {
            Style::Currency
        } else {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "style must be :decimal, :percent, or :currency",
            ));
        };

        // Extract currency option (required for currency style)
        let currency_str: Option<String> =
            kwargs.lookup::<_, Option<String>>(ruby.to_symbol("currency"))?;

        if style == Style::Currency && currency_str.is_none() {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "currency is required when style is :currency",
            ));
        }

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

        // Build decimal formatter options
        let mut decimal_options = DecimalFormatterOptions::default();
        decimal_options.grouping_strategy = Some(if use_grouping {
            GroupingStrategy::Auto
        } else {
            GroupingStrategy::Never
        });

        // Create formatter based on style
        let inner = match style {
            Style::Decimal => {
                let prefs: DecimalFormatterPreferences = (&icu_locale).into();
                let formatter = DecimalFormatter::try_new_unstable(
                    &dp.inner.as_deserializing(),
                    prefs,
                    decimal_options,
                )
                .map_err(|e| {
                    Error::new(error_class, format!("Failed to create NumberFormat: {}", e))
                })?;
                FormatterKind::Decimal(formatter)
            }
            Style::Percent => {
                let prefs: PercentFormatterPreferences = (&icu_locale).into();
                let percent_options = PercentFormatterOptions::default();
                let formatter = PercentFormatter::try_new_unstable(
                    &dp.inner.as_deserializing(),
                    prefs,
                    percent_options,
                )
                .map_err(|e| {
                    Error::new(error_class, format!("Failed to create NumberFormat: {}", e))
                })?;
                FormatterKind::Percent(formatter)
            }
            Style::Currency => {
                let currency = currency_str.as_ref().unwrap();
                let currency_tiny: TinyAsciiStr<3> = currency.parse().map_err(|_| {
                    Error::new(
                        ruby.exception_arg_error(),
                        format!("currency must be a valid 3-letter ISO 4217 code, got: {}", currency),
                    )
                })?;
                let currency_code = CurrencyCode(currency_tiny);
                let prefs: CurrencyFormatterPreferences = (&icu_locale).into();
                let currency_options = CurrencyFormatterOptions::default();
                let formatter = CurrencyFormatter::try_new_unstable(
                    &dp.inner.as_deserializing(),
                    prefs,
                    currency_options,
                )
                .map_err(|e| {
                    Error::new(error_class, format!("Failed to create NumberFormat: {}", e))
                })?;
                FormatterKind::Currency(formatter, currency_code)
            }
        };

        Ok(Self {
            inner,
            locale_str,
            style,
            use_grouping,
            currency_code: currency_str,
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
        let formatted = match &self.inner {
            FormatterKind::Decimal(formatter) => formatter.format(&decimal).to_string(),
            FormatterKind::Percent(formatter) => formatter.format(&decimal).to_string(),
            FormatterKind::Currency(formatter, currency_code) => {
                formatter.format_fixed_decimal(&decimal, *currency_code).to_string()
            }
        };
        Ok(formatted)
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
        } else if Self::is_big_decimal(ruby, number) {
            // Call to_s("F") to get fixed-point format string
            let s: String = number.funcall("to_s", ("F",))?;
            s.parse::<Decimal>().map_err(|e| {
                Error::new(
                    ruby.exception_arg_error(),
                    format!("Failed to convert BigDecimal to Decimal: {}", e),
                )
            })
        } else {
            Err(Error::new(
                ruby.exception_type_error(),
                "number must be an Integer, Float, or BigDecimal",
            ))
        }
    }

    /// Check if value is a BigDecimal
    fn is_big_decimal(ruby: &Ruby, value: Value) -> bool {
        // Try to get BigDecimal class; if bigdecimal is not loaded, return false
        if let Ok(bigdecimal_class) = ruby.eval::<Value>("defined?(BigDecimal) && BigDecimal") {
            if bigdecimal_class.is_nil() {
                return false;
            }
            if let Ok(class) = magnus::RClass::try_convert(bigdecimal_class) {
                return value.is_kind_of(class);
            }
        }
        false
    }

    /// Get the resolved options
    ///
    /// # Returns
    /// A hash with :locale, :style, :use_grouping, and optionally :currency keys
    fn resolved_options(&self) -> Result<RHash, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let hash = ruby.hash_new();
        hash.aset(ruby.to_symbol("locale"), self.locale_str.as_str())?;
        let style_sym = match self.style {
            Style::Decimal => ruby.to_symbol("decimal"),
            Style::Percent => ruby.to_symbol("percent"),
            Style::Currency => ruby.to_symbol("currency"),
        };
        hash.aset(ruby.to_symbol("style"), style_sym)?;
        hash.aset(ruby.to_symbol("use_grouping"), self.use_grouping)?;
        if let Some(ref currency) = self.currency_code {
            hash.aset(ruby.to_symbol("currency"), currency.as_str())?;
        }
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
