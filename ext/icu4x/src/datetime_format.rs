use crate::data_provider::DataProvider;
use crate::helpers;
use crate::locale::Locale;
use icu::calendar::preferences::CalendarAlgorithm;
use icu::calendar::{AnyCalendarKind, Date, Gregorian};
use icu::datetime::fieldsets::enums::{
    CompositeDateTimeFieldSet, DateAndTimeFieldSet, DateFieldSet, TimeFieldSet,
};
use icu::datetime::fieldsets::{self};
use icu::datetime::input::DateTime;
use icu::datetime::{DateTimeFormatter, DateTimeFormatterPreferences};
use icu::time::Time;
use icu::time::zone::IanaParser;
use icu_provider::buf::AsDeserializingBufferProvider;
use jiff::Timestamp;
use jiff::tz::TimeZone;
use magnus::{
    Error, ExceptionClass, RHash, RModule, Ruby, Symbol, TryConvert, Value, function, method,
    prelude::*,
};

/// Date style option
#[derive(Clone, Copy, PartialEq, Eq)]
enum DateStyle {
    Full,
    Long,
    Medium,
    Short,
}

impl DateStyle {
    fn to_symbol_name(self) -> &'static str {
        match self {
            DateStyle::Full => "full",
            DateStyle::Long => "long",
            DateStyle::Medium => "medium",
            DateStyle::Short => "short",
        }
    }
}

/// Time style option
#[derive(Clone, Copy, PartialEq, Eq)]
enum TimeStyle {
    Full,
    Long,
    Medium,
    Short,
}

impl TimeStyle {
    fn to_symbol_name(self) -> &'static str {
        match self {
            TimeStyle::Full => "full",
            TimeStyle::Long => "long",
            TimeStyle::Medium => "medium",
            TimeStyle::Short => "short",
        }
    }
}

/// Calendar option
#[derive(Clone, Copy, PartialEq, Eq)]
enum Calendar {
    Gregory,
    Japanese,
    Buddhist,
    Chinese,
    Hebrew,
    Islamic,
    Persian,
    Indian,
    Ethiopian,
    Coptic,
    Roc,
    Dangi,
}

impl Calendar {
    fn to_symbol_name(self) -> &'static str {
        match self {
            Calendar::Gregory => "gregory",
            Calendar::Japanese => "japanese",
            Calendar::Buddhist => "buddhist",
            Calendar::Chinese => "chinese",
            Calendar::Hebrew => "hebrew",
            Calendar::Islamic => "islamic",
            Calendar::Persian => "persian",
            Calendar::Indian => "indian",
            Calendar::Ethiopian => "ethiopian",
            Calendar::Coptic => "coptic",
            Calendar::Roc => "roc",
            Calendar::Dangi => "dangi",
        }
    }

    fn to_calendar_algorithm(self) -> CalendarAlgorithm {
        match self {
            Calendar::Gregory => CalendarAlgorithm::Gregory,
            Calendar::Japanese => CalendarAlgorithm::Japanese,
            Calendar::Buddhist => CalendarAlgorithm::Buddhist,
            Calendar::Chinese => CalendarAlgorithm::Chinese,
            Calendar::Hebrew => CalendarAlgorithm::Hebrew,
            Calendar::Islamic => CalendarAlgorithm::Hijri(None),
            Calendar::Persian => CalendarAlgorithm::Persian,
            Calendar::Indian => CalendarAlgorithm::Indian,
            Calendar::Ethiopian => CalendarAlgorithm::Ethiopic,
            Calendar::Coptic => CalendarAlgorithm::Coptic,
            Calendar::Roc => CalendarAlgorithm::Roc,
            Calendar::Dangi => CalendarAlgorithm::Dangi,
        }
    }

    fn from_any_calendar_kind(kind: AnyCalendarKind) -> Self {
        match kind {
            AnyCalendarKind::Buddhist => Calendar::Buddhist,
            AnyCalendarKind::Chinese => Calendar::Chinese,
            AnyCalendarKind::Coptic => Calendar::Coptic,
            AnyCalendarKind::Dangi => Calendar::Dangi,
            AnyCalendarKind::Ethiopian | AnyCalendarKind::EthiopianAmeteAlem => Calendar::Ethiopian,
            AnyCalendarKind::Gregorian => Calendar::Gregory,
            AnyCalendarKind::Hebrew => Calendar::Hebrew,
            AnyCalendarKind::Indian => Calendar::Indian,
            AnyCalendarKind::HijriTabularTypeIIFriday
            | AnyCalendarKind::HijriSimulatedMecca
            | AnyCalendarKind::HijriTabularTypeIIThursday
            | AnyCalendarKind::HijriUmmAlQura => Calendar::Islamic,
            AnyCalendarKind::Iso => Calendar::Gregory,
            AnyCalendarKind::Japanese | AnyCalendarKind::JapaneseExtended => Calendar::Japanese,
            AnyCalendarKind::Persian => Calendar::Persian,
            AnyCalendarKind::Roc => Calendar::Roc,
            _ => Calendar::Gregory,
        }
    }
}

/// Ruby wrapper for ICU4X datetime formatters
#[magnus::wrap(class = "ICU4X::DateTimeFormat", free_immediately, size)]
pub struct DateTimeFormat {
    inner: DateTimeFormatter<CompositeDateTimeFieldSet>,
    locale_str: String,
    date_style: Option<DateStyle>,
    time_style: Option<TimeStyle>,
    time_zone: Option<String>,
    jiff_timezone: Option<TimeZone>,
    calendar: Calendar,
}

// SAFETY: Ruby's GVL protects access to this type.
unsafe impl Send for DateTimeFormat {}

impl DateTimeFormat {
    /// Create a new DateTimeFormat instance
    ///
    /// # Arguments
    /// * `locale` - A Locale instance
    /// * `provider:` - A DataProvider instance
    /// * `date_style:` - :full, :long, :medium, or :short
    /// * `time_style:` - :full, :long, :medium, or :short
    /// * `time_zone:` - IANA timezone name (e.g., "Asia/Tokyo")
    /// * `calendar:` - :gregory, :japanese, :buddhist, :chinese, :hebrew, :islamic,
    ///   :persian, :indian, :ethiopian, :coptic, :roc, :dangi
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

        // Extract date_style option
        let date_style = Self::extract_date_style(ruby, &kwargs)?;

        // Extract time_style option
        let time_style = Self::extract_time_style(ruby, &kwargs)?;

        // At least one of date_style or time_style must be specified
        if date_style.is_none() && time_style.is_none() {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "at least one of date_style or time_style must be specified",
            ));
        }

        // Extract time_zone option and parse it
        let time_zone: Option<String> =
            kwargs.lookup::<_, Option<String>>(ruby.to_symbol("time_zone"))?;

        // Parse and validate the timezone if specified
        let jiff_timezone = if let Some(ref tz_str) = time_zone {
            // First validate with ICU4X's IanaParser
            let parser = IanaParser::new();
            let icu_tz = parser.parse(tz_str);
            if icu_tz.is_unknown() {
                return Err(Error::new(
                    ruby.exception_arg_error(),
                    format!("invalid IANA timezone: {}", tz_str),
                ));
            }
            // Then create jiff TimeZone for offset calculation
            let jiff_tz = TimeZone::get(tz_str).map_err(|e| {
                Error::new(
                    ruby.exception_arg_error(),
                    format!("invalid IANA timezone: {} ({})", tz_str, e),
                )
            })?;
            Some(jiff_tz)
        } else {
            None
        };

        // Extract calendar option
        let calendar = Self::extract_calendar(ruby, &kwargs)?;

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

        // Create field set based on date_style and time_style
        let field_set = Self::create_field_set(date_style, time_style);

        // Create formatter with calendar preference
        let mut prefs: DateTimeFormatterPreferences = (&icu_locale).into();
        if let Some(cal) = calendar {
            prefs.calendar_algorithm = Some(cal.to_calendar_algorithm());
        }

        let formatter =
            DateTimeFormatter::try_new_unstable(&dp.inner.as_deserializing(), prefs, field_set)
                .map_err(|e| {
                    Error::new(
                        error_class,
                        format!("Failed to create DateTimeFormat: {}", e),
                    )
                })?;

        // Get the resolved calendar from the formatter
        let resolved_calendar = Calendar::from_any_calendar_kind(formatter.calendar().kind());

        Ok(Self {
            inner: formatter,
            locale_str,
            date_style,
            time_style,
            time_zone,
            jiff_timezone,
            calendar: resolved_calendar,
        })
    }

    /// Extract calendar option from kwargs
    fn extract_calendar(ruby: &Ruby, kwargs: &RHash) -> Result<Option<Calendar>, Error> {
        let calendar_value: Option<Symbol> =
            kwargs.lookup::<_, Option<Symbol>>(ruby.to_symbol("calendar"))?;

        let Some(sym) = calendar_value else {
            return Ok(None);
        };

        let gregory = ruby.to_symbol("gregory");
        let japanese = ruby.to_symbol("japanese");
        let buddhist = ruby.to_symbol("buddhist");
        let chinese = ruby.to_symbol("chinese");
        let hebrew = ruby.to_symbol("hebrew");
        let islamic = ruby.to_symbol("islamic");
        let persian = ruby.to_symbol("persian");
        let indian = ruby.to_symbol("indian");
        let ethiopian = ruby.to_symbol("ethiopian");
        let coptic = ruby.to_symbol("coptic");
        let roc = ruby.to_symbol("roc");
        let dangi = ruby.to_symbol("dangi");

        if sym.equal(gregory)? {
            Ok(Some(Calendar::Gregory))
        } else if sym.equal(japanese)? {
            Ok(Some(Calendar::Japanese))
        } else if sym.equal(buddhist)? {
            Ok(Some(Calendar::Buddhist))
        } else if sym.equal(chinese)? {
            Ok(Some(Calendar::Chinese))
        } else if sym.equal(hebrew)? {
            Ok(Some(Calendar::Hebrew))
        } else if sym.equal(islamic)? {
            Ok(Some(Calendar::Islamic))
        } else if sym.equal(persian)? {
            Ok(Some(Calendar::Persian))
        } else if sym.equal(indian)? {
            Ok(Some(Calendar::Indian))
        } else if sym.equal(ethiopian)? {
            Ok(Some(Calendar::Ethiopian))
        } else if sym.equal(coptic)? {
            Ok(Some(Calendar::Coptic))
        } else if sym.equal(roc)? {
            Ok(Some(Calendar::Roc))
        } else if sym.equal(dangi)? {
            Ok(Some(Calendar::Dangi))
        } else {
            Err(Error::new(
                ruby.exception_arg_error(),
                "calendar must be :gregory, :japanese, :buddhist, :chinese, :hebrew, :islamic, :persian, :indian, :ethiopian, :coptic, :roc, or :dangi",
            ))
        }
    }

    /// Extract date_style option from kwargs
    fn extract_date_style(ruby: &Ruby, kwargs: &RHash) -> Result<Option<DateStyle>, Error> {
        let style_value: Option<Symbol> =
            kwargs.lookup::<_, Option<Symbol>>(ruby.to_symbol("date_style"))?;

        let Some(sym) = style_value else {
            return Ok(None);
        };

        let full = ruby.to_symbol("full");
        let long = ruby.to_symbol("long");
        let medium = ruby.to_symbol("medium");
        let short = ruby.to_symbol("short");

        if sym.equal(full)? {
            Ok(Some(DateStyle::Full))
        } else if sym.equal(long)? {
            Ok(Some(DateStyle::Long))
        } else if sym.equal(medium)? {
            Ok(Some(DateStyle::Medium))
        } else if sym.equal(short)? {
            Ok(Some(DateStyle::Short))
        } else {
            Err(Error::new(
                ruby.exception_arg_error(),
                "date_style must be :full, :long, :medium, or :short",
            ))
        }
    }

    /// Extract time_style option from kwargs
    fn extract_time_style(ruby: &Ruby, kwargs: &RHash) -> Result<Option<TimeStyle>, Error> {
        let style_value: Option<Symbol> =
            kwargs.lookup::<_, Option<Symbol>>(ruby.to_symbol("time_style"))?;

        let Some(sym) = style_value else {
            return Ok(None);
        };

        let full = ruby.to_symbol("full");
        let long = ruby.to_symbol("long");
        let medium = ruby.to_symbol("medium");
        let short = ruby.to_symbol("short");

        if sym.equal(full)? {
            Ok(Some(TimeStyle::Full))
        } else if sym.equal(long)? {
            Ok(Some(TimeStyle::Long))
        } else if sym.equal(medium)? {
            Ok(Some(TimeStyle::Medium))
        } else if sym.equal(short)? {
            Ok(Some(TimeStyle::Short))
        } else {
            Err(Error::new(
                ruby.exception_arg_error(),
                "time_style must be :full, :long, :medium, or :short",
            ))
        }
    }

    /// Create field set based on date_style and time_style
    fn create_field_set(
        date_style: Option<DateStyle>,
        time_style: Option<TimeStyle>,
    ) -> CompositeDateTimeFieldSet {
        match (date_style, time_style) {
            (Some(ds), Some(ts)) => {
                // Both date and time
                let ymdt = match (ds, ts) {
                    (DateStyle::Full, _) | (DateStyle::Long, _) => fieldsets::YMDT::long(),
                    (DateStyle::Medium, _) => fieldsets::YMDT::medium(),
                    (DateStyle::Short, _) => fieldsets::YMDT::short(),
                };
                CompositeDateTimeFieldSet::DateTime(DateAndTimeFieldSet::YMDT(ymdt))
            }
            (Some(ds), None) => {
                // Date only
                let ymd = match ds {
                    DateStyle::Full | DateStyle::Long => fieldsets::YMD::long(),
                    DateStyle::Medium => fieldsets::YMD::medium(),
                    DateStyle::Short => fieldsets::YMD::short(),
                };
                CompositeDateTimeFieldSet::Date(DateFieldSet::YMD(ymd))
            }
            (None, Some(ts)) => {
                // Time only
                let t = match ts {
                    TimeStyle::Full | TimeStyle::Long => fieldsets::T::long(),
                    TimeStyle::Medium => fieldsets::T::medium(),
                    TimeStyle::Short => fieldsets::T::short(),
                };
                CompositeDateTimeFieldSet::Time(TimeFieldSet::T(t))
            }
            (None, None) => {
                // Should not happen due to validation
                unreachable!("at least one of date_style or time_style must be specified")
            }
        }
    }

    /// Format a Ruby Time object
    ///
    /// # Arguments
    /// * `time` - A Ruby Time object
    ///
    /// # Returns
    /// A formatted string
    fn format(&self, time: Value) -> Result<String, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");

        // Validate that time is a Time object
        let time_class: Value = ruby.eval("Time")?;
        if !time.is_kind_of(magnus::RClass::try_convert(time_class)?) {
            return Err(Error::new(
                ruby.exception_type_error(),
                "argument must be a Time object",
            ));
        }

        // Convert Ruby Time to ICU4X DateTime, applying timezone if specified
        let datetime = self.convert_time_to_datetime(&ruby, time)?;

        // Format the datetime
        let formatted = self.inner.format(&datetime);
        Ok(formatted.to_string())
    }

    /// Convert Ruby Time to ICU4X DateTime<Gregorian>
    ///
    /// If time_zone is specified, the UTC time is converted to local time in that timezone.
    /// Otherwise, the time is treated as UTC.
    fn convert_time_to_datetime(
        &self,
        ruby: &Ruby,
        time: Value,
    ) -> Result<DateTime<Gregorian>, Error> {
        // Get UTC time from Ruby Time object
        let utc_time: Value = time.funcall("getutc", ())?;

        let utc_year: i32 = utc_time.funcall("year", ())?;
        let utc_month: i32 = utc_time.funcall("month", ())?;
        let utc_day: i32 = utc_time.funcall("day", ())?;
        let utc_hour: i32 = utc_time.funcall("hour", ())?;
        let utc_min: i32 = utc_time.funcall("min", ())?;
        let utc_sec: i32 = utc_time.funcall("sec", ())?;

        // Get year, month, day, hour, min, sec in the target timezone
        let (year, month, day, hour, min, sec) = if let Some(ref tz) = self.jiff_timezone {
            // Create a jiff Timestamp from UTC components
            let timestamp = Timestamp::from_second(utc_time.funcall::<_, _, i64>("to_i", ())?)
                .map_err(|e| {
                    Error::new(
                        ruby.exception_arg_error(),
                        format!("Invalid timestamp: {}", e),
                    )
                })?;

            // Convert to local time in the target timezone
            let zoned = timestamp.to_zoned(tz.clone());
            let dt = zoned.datetime();

            (
                dt.year() as i32,
                dt.month() as i32,
                dt.day() as i32,
                dt.hour() as i32,
                dt.minute() as i32,
                dt.second() as i32,
            )
        } else {
            // No timezone specified, use UTC
            (utc_year, utc_month, utc_day, utc_hour, utc_min, utc_sec)
        };

        // Create ISO date and convert to Gregorian
        let iso_date = Date::try_new_iso(year, month as u8, day as u8)
            .map_err(|e| Error::new(ruby.exception_arg_error(), format!("Invalid date: {}", e)))?;
        let gregorian_date = iso_date.to_calendar(Gregorian);

        // Create time
        let time_of_day = Time::try_new(hour as u8, min as u8, sec as u8, 0)
            .map_err(|e| Error::new(ruby.exception_arg_error(), format!("Invalid time: {}", e)))?;

        Ok(DateTime {
            date: gregorian_date,
            time: time_of_day,
        })
    }

    /// Get the resolved options
    ///
    /// # Returns
    /// A hash with :locale, :calendar, :date_style, :time_style, and optionally :time_zone
    fn resolved_options(&self) -> Result<RHash, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let hash = ruby.hash_new();

        hash.aset(ruby.to_symbol("locale"), self.locale_str.as_str())?;
        hash.aset(
            ruby.to_symbol("calendar"),
            ruby.to_symbol(self.calendar.to_symbol_name()),
        )?;

        if let Some(ds) = self.date_style {
            hash.aset(
                ruby.to_symbol("date_style"),
                ruby.to_symbol(ds.to_symbol_name()),
            )?;
        }

        if let Some(ts) = self.time_style {
            hash.aset(
                ruby.to_symbol("time_style"),
                ruby.to_symbol(ts.to_symbol_name()),
            )?;
        }

        if let Some(ref tz) = self.time_zone {
            hash.aset(ruby.to_symbol("time_zone"), tz.as_str())?;
        }

        Ok(hash)
    }
}

pub fn init(ruby: &Ruby, module: &RModule) -> Result<(), Error> {
    let class = module.define_class("DateTimeFormat", ruby.class_object())?;
    class.define_singleton_method("new", function!(DateTimeFormat::new, -1))?;
    class.define_method("format", method!(DateTimeFormat::format, 1))?;
    class.define_method(
        "resolved_options",
        method!(DateTimeFormat::resolved_options, 0),
    )?;
    Ok(())
}
