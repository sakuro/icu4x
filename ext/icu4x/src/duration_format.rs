use crate::data_provider::DataProvider;
use crate::locale::Locale;
use icu::experimental::duration::options::{BaseStyle, DurationFormatterOptions};
use icu::experimental::duration::{
    Duration, DurationFormatter, DurationFormatterPreferences,
};
use icu_experimental::duration::formatter::ValidatedDurationFormatterOptions;
use icu_provider::buf::AsDeserializingBufferProvider;
use magnus::{
    Error, ExceptionClass, RHash, RModule, Ruby, Symbol, TryConvert, Value, function, method,
    prelude::*,
};

/// The style of duration formatting
#[derive(Clone, Copy, PartialEq, Eq)]
enum Style {
    Long,
    Short,
    Narrow,
    Digital,
}

impl Style {
    fn to_base_style(self) -> BaseStyle {
        match self {
            Style::Long => BaseStyle::Long,
            Style::Short => BaseStyle::Short,
            Style::Narrow => BaseStyle::Narrow,
            Style::Digital => BaseStyle::Digital,
        }
    }

    fn to_symbol_name(self) -> &'static str {
        match self {
            Style::Long => "long",
            Style::Short => "short",
            Style::Narrow => "narrow",
            Style::Digital => "digital",
        }
    }
}

/// Ruby wrapper for ICU4X DurationFormatter
#[magnus::wrap(class = "ICU4X::DurationFormat", free_immediately, size)]
pub struct DurationFormat {
    inner: DurationFormatter,
    locale_str: String,
    style: Style,
}

// SAFETY: Ruby's GVL protects access to this type.
unsafe impl Send for DurationFormat {}

impl DurationFormat {
    /// Create a new DurationFormat instance
    ///
    /// # Arguments
    /// * `locale` - A Locale instance
    /// * `provider:` - A DataProvider instance
    /// * `style:` - :long (default), :short, :narrow, or :digital
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

        // Extract style option (default: :long)
        let style_value: Option<Symbol> =
            kwargs.lookup::<_, Option<Symbol>>(ruby.to_symbol("style"))?;
        let long_sym = ruby.to_symbol("long");
        let short_sym = ruby.to_symbol("short");
        let narrow_sym = ruby.to_symbol("narrow");
        let digital_sym = ruby.to_symbol("digital");
        let style_sym = style_value.unwrap_or(long_sym);

        let style = if style_sym.equal(long_sym)? {
            Style::Long
        } else if style_sym.equal(short_sym)? {
            Style::Short
        } else if style_sym.equal(narrow_sym)? {
            Style::Narrow
        } else if style_sym.equal(digital_sym)? {
            Style::Digital
        } else {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "style must be :long, :short, :narrow, or :digital",
            ));
        };

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

        // Build formatter options
        let mut options = DurationFormatterOptions::default();
        options.base = style.to_base_style();
        let validated_options = ValidatedDurationFormatterOptions::validate(options).map_err(|e| {
            Error::new(
                error_class,
                format!("Invalid DurationFormat options: {:?}", e),
            )
        })?;

        // Create formatter
        let prefs: DurationFormatterPreferences = (&icu_locale).into();
        let formatter =
            DurationFormatter::try_new_unstable(&dp.inner.as_deserializing(), prefs, validated_options)
                .map_err(|e| {
                    Error::new(
                        error_class,
                        format!("Failed to create DurationFormat: {}", e),
                    )
                })?;

        Ok(Self {
            inner: formatter,
            locale_str,
            style,
        })
    }

    /// Format a duration
    ///
    /// # Arguments
    /// * `duration` - A Hash with duration components
    ///
    /// # Returns
    /// A formatted string
    fn format(&self, duration_hash: RHash) -> Result<String, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");

        // Extract duration components from hash
        let years = Self::extract_u64(&ruby, &duration_hash, "years")?;
        let months = Self::extract_u64(&ruby, &duration_hash, "months")?;
        let weeks = Self::extract_u64(&ruby, &duration_hash, "weeks")?;
        let days = Self::extract_u64(&ruby, &duration_hash, "days")?;
        let hours = Self::extract_u64(&ruby, &duration_hash, "hours")?;
        let minutes = Self::extract_u64(&ruby, &duration_hash, "minutes")?;
        let seconds = Self::extract_u64(&ruby, &duration_hash, "seconds")?;
        let milliseconds = Self::extract_u64(&ruby, &duration_hash, "milliseconds")?;
        let microseconds = Self::extract_u64(&ruby, &duration_hash, "microseconds")?;
        let nanoseconds = Self::extract_u64(&ruby, &duration_hash, "nanoseconds")?;

        // Check that at least one component is provided
        if years == 0
            && months == 0
            && weeks == 0
            && days == 0
            && hours == 0
            && minutes == 0
            && seconds == 0
            && milliseconds == 0
            && microseconds == 0
            && nanoseconds == 0
        {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "duration must have at least one non-zero component",
            ));
        }

        // Create Duration
        let duration = Duration {
            years,
            months,
            weeks,
            days,
            hours,
            minutes,
            seconds,
            milliseconds,
            microseconds,
            nanoseconds,
            ..Default::default()
        };

        let formatted = self.inner.format(&duration);
        Ok(formatted.to_string())
    }

    /// Extract a u64 value from hash
    fn extract_u64(ruby: &Ruby, hash: &RHash, key: &str) -> Result<u64, Error> {
        let value: Option<i64> = hash.lookup::<_, Option<i64>>(ruby.to_symbol(key))?;
        match value {
            Some(v) if v < 0 => Err(Error::new(
                ruby.exception_arg_error(),
                format!("{} must be non-negative", key),
            )),
            Some(v) => Ok(v as u64),
            None => Ok(0),
        }
    }

    /// Get the resolved options
    ///
    /// # Returns
    /// A hash with :locale and :style keys
    fn resolved_options(&self) -> Result<RHash, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let hash = ruby.hash_new();
        hash.aset(ruby.to_symbol("locale"), self.locale_str.as_str())?;
        hash.aset(
            ruby.to_symbol("style"),
            ruby.to_symbol(self.style.to_symbol_name()),
        )?;
        Ok(hash)
    }
}

pub fn init(ruby: &Ruby, module: &RModule) -> Result<(), Error> {
    let class = module.define_class("DurationFormat", ruby.class_object())?;
    class.define_singleton_method("new", function!(DurationFormat::new, -1))?;
    class.define_method("format", method!(DurationFormat::format, 1))?;
    class.define_method(
        "resolved_options",
        method!(DurationFormat::resolved_options, 0),
    )?;
    Ok(())
}
