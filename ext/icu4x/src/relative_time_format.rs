use crate::data_provider::DataProvider;
use crate::helpers;
use crate::parts_collector::{PartsCollector, parts_to_ruby_array};
use fixed_decimal::Decimal;
use icu::decimal::parts as decimal_parts;
use icu::experimental::relativetime::options::Numeric;
use icu::experimental::relativetime::{
    RelativeTimeFormatter, RelativeTimeFormatterOptions, RelativeTimeFormatterPreferences,
};
use icu_provider::buf::AsDeserializingBufferProvider;
use icu4x_macros::RubySymbol;
use magnus::{
    Error, ExceptionClass, RArray, RHash, RModule, Ruby, Symbol, TryConvert, Value, function,
    method, prelude::*,
};
use writeable::{Part, Writeable};

/// The style of relative time formatting
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
enum Style {
    Long,
    Short,
    Narrow,
}

/// The numeric mode for relative time formatting
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
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
}

/// Time unit for relative time formatting
#[derive(Clone, Copy, PartialEq, Eq, Hash, RubySymbol)]
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

/// Convert ICU4X relative time Part to Ruby symbol name
fn part_to_symbol_name(part: &Part) -> &'static str {
    if *part == decimal_parts::INTEGER {
        "integer"
    } else if part.category == "relativetime" && part.value == "literal" {
        "literal"
    } else {
        "literal"
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
        let (icu_locale, locale_str) = helpers::extract_locale(ruby, args)?;

        // Get kwargs (optional)
        let kwargs: RHash = if args.len() > 1 {
            TryConvert::try_convert(args[1])?
        } else {
            ruby.hash_new()
        };

        // Resolve provider: use explicit or fall back to default
        let resolved_provider = helpers::resolve_provider(ruby, &kwargs)?;

        // Extract style option (default: :long)
        let style = helpers::extract_symbol(ruby, &kwargs, "style", Style::from_ruby_symbol)?
            .unwrap_or(Style::Long);

        // Extract numeric option (default: :always)
        let numeric =
            helpers::extract_symbol(ruby, &kwargs, "numeric", NumericMode::from_ruby_symbol)?
                .unwrap_or(NumericMode::Always);

        // Get the error exception class
        let error_class = helpers::get_exception_class(ruby, "ICU4X::Error");

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
        let (formatter, decimal) = self.prepare_value(&ruby, value, unit)?;
        let formatted = formatter.format(decimal);
        Ok(formatted.to_string())
    }

    /// Format a relative time value and return an array of FormattedPart
    ///
    /// # Arguments
    /// * `value` - The relative time value (negative = past, positive = future)
    /// * `unit` - The time unit (:second, :minute, :hour, :day, :week, :month, :quarter, :year)
    ///
    /// # Returns
    /// An array of FormattedPart objects with :type and :value
    fn format_to_parts(&self, value: i64, unit: Symbol) -> Result<RArray, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let (formatter, decimal) = self.prepare_value(&ruby, value, unit)?;

        let formatted = formatter.format(decimal);
        let mut collector = PartsCollector::new();
        formatted
            .write_to_parts(&mut collector)
            .map_err(|e| Error::new(ruby.exception_runtime_error(), format!("{}", e)))?;

        parts_to_ruby_array(&ruby, collector, part_to_symbol_name)
    }

    /// Prepare value for formatting.
    ///
    /// Validates unit and converts value to Decimal.
    fn prepare_value<'a>(
        &'a self,
        ruby: &Ruby,
        value: i64,
        unit: Symbol,
    ) -> Result<(&'a RelativeTimeFormatter, Decimal), Error> {
        let unit = Unit::from_ruby_symbol(ruby, unit, "unit")?;
        let formatter = &self.formatters[unit.index()];
        let decimal = Decimal::from(value);
        Ok((formatter, decimal))
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
        "format_to_parts",
        method!(RelativeTimeFormat::format_to_parts, 2),
    )?;
    class.define_method(
        "resolved_options",
        method!(RelativeTimeFormat::resolved_options, 0),
    )?;
    Ok(())
}
