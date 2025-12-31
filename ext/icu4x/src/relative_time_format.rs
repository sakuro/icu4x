use crate::data_provider::DataProvider;
use crate::helpers;
use crate::locale::Locale;
use fixed_decimal::Decimal;
use icu::experimental::relativetime::options::Numeric;
use icu::experimental::relativetime::{
    RelativeTimeFormatter, RelativeTimeFormatterOptions, RelativeTimeFormatterPreferences,
};
use icu_provider::buf::AsDeserializingBufferProvider;
use magnus::{
    Error, ExceptionClass, RHash, RModule, Ruby, Symbol, TryConvert, Value, function, method,
    prelude::*,
};

/// The style of relative time formatting
#[derive(Clone, Copy, PartialEq, Eq)]
enum Style {
    Long,
    Short,
    Narrow,
}

impl Style {
    fn to_symbol_name(self) -> &'static str {
        match self {
            Style::Long => "long",
            Style::Short => "short",
            Style::Narrow => "narrow",
        }
    }
}

/// The numeric mode for relative time formatting
#[derive(Clone, Copy, PartialEq, Eq)]
enum NumericMode {
    Always,
    Auto,
}

impl NumericMode {
    fn to_icu_numeric(self) -> Numeric {
        match self {
            NumericMode::Always => Numeric::Always,
            NumericMode::Auto => Numeric::Auto,
        }
    }

    fn to_symbol_name(self) -> &'static str {
        match self {
            NumericMode::Always => "always",
            NumericMode::Auto => "auto",
        }
    }
}

/// Time unit for relative time formatting
#[derive(Clone, Copy, PartialEq, Eq, Hash)]
enum Unit {
    Second,
    Minute,
    Hour,
    Day,
    Week,
    Month,
    Quarter,
    Year,
}

impl Unit {
    fn from_symbol(ruby: &Ruby, sym: Symbol) -> Result<Self, Error> {
        let second_sym = ruby.to_symbol("second");
        let minute_sym = ruby.to_symbol("minute");
        let hour_sym = ruby.to_symbol("hour");
        let day_sym = ruby.to_symbol("day");
        let week_sym = ruby.to_symbol("week");
        let month_sym = ruby.to_symbol("month");
        let quarter_sym = ruby.to_symbol("quarter");
        let year_sym = ruby.to_symbol("year");

        if sym.equal(second_sym)? {
            Ok(Unit::Second)
        } else if sym.equal(minute_sym)? {
            Ok(Unit::Minute)
        } else if sym.equal(hour_sym)? {
            Ok(Unit::Hour)
        } else if sym.equal(day_sym)? {
            Ok(Unit::Day)
        } else if sym.equal(week_sym)? {
            Ok(Unit::Week)
        } else if sym.equal(month_sym)? {
            Ok(Unit::Month)
        } else if sym.equal(quarter_sym)? {
            Ok(Unit::Quarter)
        } else if sym.equal(year_sym)? {
            Ok(Unit::Year)
        } else {
            Err(Error::new(
                ruby.exception_arg_error(),
                "unit must be :second, :minute, :hour, :day, :week, :month, :quarter, or :year",
            ))
        }
    }

    fn index(self) -> usize {
        match self {
            Unit::Second => 0,
            Unit::Minute => 1,
            Unit::Hour => 2,
            Unit::Day => 3,
            Unit::Week => 4,
            Unit::Month => 5,
            Unit::Quarter => 6,
            Unit::Year => 7,
        }
    }
}

/// Ruby wrapper for ICU4X RelativeTimeFormatter
///
/// Stores formatters for all 8 time units for the selected style.
#[magnus::wrap(class = "ICU4X::RelativeTimeFormat", free_immediately, size)]
pub struct RelativeTimeFormat {
    formatters: [RelativeTimeFormatter; 8],
    locale_str: String,
    style: Style,
    numeric: NumericMode,
}

// SAFETY: Ruby's GVL protects access to this type.
unsafe impl Send for RelativeTimeFormat {}

impl RelativeTimeFormat {
    /// Create a new RelativeTimeFormat instance
    ///
    /// # Arguments
    /// * `locale` - A Locale instance
    /// * `provider:` - A DataProvider instance
    /// * `style:` - :long (default), :short, :narrow
    /// * `numeric:` - :always (default), :auto
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

        // Get kwargs (optional)
        let kwargs: RHash = if args.len() > 1 {
            TryConvert::try_convert(args[1])?
        } else {
            ruby.hash_new()
        };

        // Resolve provider: use explicit or fall back to default
        let resolved_provider = helpers::resolve_provider(ruby, &kwargs)?;

        // Extract style option (default: :long)
        let style_value: Option<Symbol> =
            kwargs.lookup::<_, Option<Symbol>>(ruby.to_symbol("style"))?;
        let long_sym = ruby.to_symbol("long");
        let short_sym = ruby.to_symbol("short");
        let narrow_sym = ruby.to_symbol("narrow");
        let style_sym = style_value.unwrap_or(long_sym);

        let style = if style_sym.equal(long_sym)? {
            Style::Long
        } else if style_sym.equal(short_sym)? {
            Style::Short
        } else if style_sym.equal(narrow_sym)? {
            Style::Narrow
        } else {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "style must be :long, :short, or :narrow",
            ));
        };

        // Extract numeric option (default: :always)
        let numeric_value: Option<Symbol> =
            kwargs.lookup::<_, Option<Symbol>>(ruby.to_symbol("numeric"))?;
        let always_sym = ruby.to_symbol("always");
        let auto_sym = ruby.to_symbol("auto");
        let numeric_sym = numeric_value.unwrap_or(always_sym);

        let numeric = if numeric_sym.equal(always_sym)? {
            NumericMode::Always
        } else if numeric_sym.equal(auto_sym)? {
            NumericMode::Auto
        } else {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "numeric must be :always or :auto",
            ));
        };

        // Get the error exception class
        let error_class: ExceptionClass = ruby
            .eval("ICU4X::Error")
            .unwrap_or_else(|_| ruby.exception_runtime_error());

        // Get the DataProvider
        let dp: &DataProvider = TryConvert::try_convert(resolved_provider).map_err(|_| {
            Error::new(
                ruby.exception_type_error(),
                "provider must be a DataProvider",
            )
        })?;

        // Build formatter options
        let options = RelativeTimeFormatterOptions {
            numeric: numeric.to_icu_numeric(),
        };
        let prefs: RelativeTimeFormatterPreferences = (&icu_locale).into();

        // Create formatters for all units based on style
        let formatters = Self::create_formatters(dp, prefs, options, style, error_class)?;

        Ok(Self {
            formatters,
            locale_str,
            style,
            numeric,
        })
    }

    /// Create formatters for all 8 units
    fn create_formatters(
        dp: &DataProvider,
        prefs: RelativeTimeFormatterPreferences,
        options: RelativeTimeFormatterOptions,
        style: Style,
        error_class: ExceptionClass,
    ) -> Result<[RelativeTimeFormatter; 8], Error> {
        let provider = &dp.inner.as_deserializing();

        macro_rules! create_formatter {
            ($long:ident, $short:ident, $narrow:ident) => {
                match style {
                    Style::Long => RelativeTimeFormatter::$long(provider, prefs, options),
                    Style::Short => RelativeTimeFormatter::$short(provider, prefs, options),
                    Style::Narrow => RelativeTimeFormatter::$narrow(provider, prefs, options),
                }
                .map_err(|e| {
                    Error::new(
                        error_class,
                        format!("Failed to create RelativeTimeFormat: {}", e),
                    )
                })
            };
        }

        let second = create_formatter!(
            try_new_long_second_unstable,
            try_new_short_second_unstable,
            try_new_narrow_second_unstable
        )?;
        let minute = create_formatter!(
            try_new_long_minute_unstable,
            try_new_short_minute_unstable,
            try_new_narrow_minute_unstable
        )?;
        let hour = create_formatter!(
            try_new_long_hour_unstable,
            try_new_short_hour_unstable,
            try_new_narrow_hour_unstable
        )?;
        let day = create_formatter!(
            try_new_long_day_unstable,
            try_new_short_day_unstable,
            try_new_narrow_day_unstable
        )?;
        let week = create_formatter!(
            try_new_long_week_unstable,
            try_new_short_week_unstable,
            try_new_narrow_week_unstable
        )?;
        let month = create_formatter!(
            try_new_long_month_unstable,
            try_new_short_month_unstable,
            try_new_narrow_month_unstable
        )?;
        let quarter = create_formatter!(
            try_new_long_quarter_unstable,
            try_new_short_quarter_unstable,
            try_new_narrow_quarter_unstable
        )?;
        let year = create_formatter!(
            try_new_long_year_unstable,
            try_new_short_year_unstable,
            try_new_narrow_year_unstable
        )?;

        Ok([second, minute, hour, day, week, month, quarter, year])
    }

    /// Format a relative time value
    ///
    /// # Arguments
    /// * `value` - The relative time value (negative = past, positive = future)
    /// * `unit` - The time unit (:second, :minute, :hour, :day, :week, :month, :quarter, :year)
    ///
    /// # Returns
    /// A formatted string
    fn format(&self, value: i64, unit: Symbol) -> Result<String, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");

        let unit = Unit::from_symbol(&ruby, unit)?;
        let formatter = &self.formatters[unit.index()];

        // Convert i64 to Decimal
        let decimal = Decimal::from(value);

        let formatted = formatter.format(decimal);
        Ok(formatted.to_string())
    }

    /// Get the resolved options
    ///
    /// # Returns
    /// A hash with :locale, :style, and :numeric keys
    fn resolved_options(&self) -> Result<RHash, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let hash = ruby.hash_new();
        hash.aset(ruby.to_symbol("locale"), self.locale_str.as_str())?;
        hash.aset(
            ruby.to_symbol("style"),
            ruby.to_symbol(self.style.to_symbol_name()),
        )?;
        hash.aset(
            ruby.to_symbol("numeric"),
            ruby.to_symbol(self.numeric.to_symbol_name()),
        )?;
        Ok(hash)
    }
}

pub fn init(ruby: &Ruby, module: &RModule) -> Result<(), Error> {
    let class = module.define_class("RelativeTimeFormat", ruby.class_object())?;
    class.define_singleton_method("new", function!(RelativeTimeFormat::new, -1))?;
    class.define_method("format", method!(RelativeTimeFormat::format, 2))?;
    class.define_method(
        "resolved_options",
        method!(RelativeTimeFormat::resolved_options, 0),
    )?;
    Ok(())
}
