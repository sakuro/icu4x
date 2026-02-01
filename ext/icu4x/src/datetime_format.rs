use crate::data_provider::DataProvider;
use crate::helpers;
use crate::parts_collector::{PartsCollector, parts_to_ruby_array};
use icu::calendar::preferences::CalendarAlgorithm;
use icu::calendar::{AnyCalendarKind, Date, Gregorian};
use icu::datetime::fieldsets::enums::{
    CalendarPeriodFieldSet, CompositeDateTimeFieldSet, DateAndTimeFieldSet, DateFieldSet,
    TimeFieldSet,
};
use icu::datetime::fieldsets::{self};
use icu::datetime::options::Length;
use icu::datetime::input::DateTime;
use icu::datetime::parts as dt_parts;
use icu::datetime::{DateTimeFormatter, DateTimeFormatterPreferences};
use icu::locale::preferences::extensions::unicode::keywords::HourCycle as IcuHourCycle;
use icu::time::Time;
use icu::time::zone::IanaParser;
use icu_provider::buf::AsDeserializingBufferProvider;
use icu4x_macros::RubySymbol;
use jiff::Timestamp;
use jiff::tz::TimeZone;
use magnus::{Error, RArray, RHash, RModule, Ruby, TryConvert, Value, function, method, prelude::*};
use writeable::{Part, Writeable};

/// Date style option
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
enum DateStyle {
    Full,
    Long,
    Medium,
    Short,
}

/// Time style option
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
enum TimeStyle {
    Full,
    Long,
    Medium,
    Short,
}

/// Hour cycle option
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
enum HourCycle {
    H11,
    H12,
    H23,
}

impl HourCycle {
    fn to_icu_hour_cycle(self) -> IcuHourCycle {
        match self {
            HourCycle::H11 => IcuHourCycle::H11,
            HourCycle::H12 => IcuHourCycle::H12,
            HourCycle::H23 => IcuHourCycle::H23,
        }
    }
}

/// Year component option
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
enum YearStyle {
    Numeric,
    TwoDigit,
}

/// Month component option
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
enum MonthStyle {
    Numeric,
    TwoDigit,
    Long,
    Short,
    Narrow,
}

/// Day component option
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
enum DayStyle {
    Numeric,
    TwoDigit,
}

/// Weekday component option
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
enum WeekdayStyle {
    Long,
    Short,
    Narrow,
}

/// Hour component option
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
enum HourStyle {
    Numeric,
    TwoDigit,
}

/// Minute component option
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
enum MinuteStyle {
    Numeric,
    TwoDigit,
}

/// Second component option
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
enum SecondStyle {
    Numeric,
    TwoDigit,
}

/// Component options for date/time formatting
#[derive(Clone, Copy, Default)]
struct ComponentOptions {
    year: Option<YearStyle>,
    month: Option<MonthStyle>,
    day: Option<DayStyle>,
    weekday: Option<WeekdayStyle>,
    hour: Option<HourStyle>,
    minute: Option<MinuteStyle>,
    second: Option<SecondStyle>,
}

impl ComponentOptions {
    fn has_date_components(&self) -> bool {
        self.year.is_some() || self.month.is_some() || self.day.is_some() || self.weekday.is_some()
    }

    fn has_time_components(&self) -> bool {
        self.hour.is_some() || self.minute.is_some() || self.second.is_some()
    }

    fn is_empty(&self) -> bool {
        !self.has_date_components() && !self.has_time_components()
    }

    /// Determine the appropriate ICU4X Length based on component option values.
    ///
    /// When text-based month or weekday styles (:long, :short, :narrow) are specified,
    /// we use Length::Long to ensure the format uses localized text patterns
    /// (e.g., "2026年2月" in Japanese instead of "2026/02").
    ///
    /// This matches JavaScript Intl.DateTimeFormat behavior where specifying
    /// month: "short" produces text-based formats with abbreviated month names,
    /// not numeric formats.
    ///
    /// - If any text-based component (:long, :short, :narrow) → Length::Long
    /// - Default (all numeric) → Length::Short
    fn determine_length(&self) -> Length {
        // Check for any text-based month or weekday option
        let has_text_month = matches!(
            self.month,
            Some(MonthStyle::Long) | Some(MonthStyle::Short) | Some(MonthStyle::Narrow)
        );
        let has_text_weekday = matches!(
            self.weekday,
            Some(WeekdayStyle::Long) | Some(WeekdayStyle::Short) | Some(WeekdayStyle::Narrow)
        );

        if has_text_month || has_text_weekday {
            return Length::Long;
        }

        // Default for numeric-only options
        Length::Short
    }
}

/// Calendar option
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
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

/// Convert ICU4X datetime Part to Ruby symbol name
fn part_to_symbol_name(part: &Part) -> &'static str {
    if *part == dt_parts::YEAR {
        "year"
    } else if *part == dt_parts::MONTH {
        "month"
    } else if *part == dt_parts::DAY {
        "day"
    } else if *part == dt_parts::WEEKDAY {
        "weekday"
    } else if *part == dt_parts::HOUR {
        "hour"
    } else if *part == dt_parts::MINUTE {
        "minute"
    } else if *part == dt_parts::SECOND {
        "second"
    } else if *part == dt_parts::DAY_PERIOD {
        "day_period"
    } else if *part == dt_parts::ERA {
        "era"
    } else if *part == dt_parts::TIME_ZONE_NAME {
        "time_zone_name"
    } else {
        "literal"
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
    hour_cycle: Option<HourCycle>,
    component_options: Option<ComponentOptions>,
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
    /// * `hour_cycle:` - :h11, :h12, or :h23
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

        // Extract date_style option
        let date_style =
            helpers::extract_symbol(ruby, &kwargs, "date_style", DateStyle::from_ruby_symbol)?;

        // Extract time_style option
        let time_style =
            helpers::extract_symbol(ruby, &kwargs, "time_style", TimeStyle::from_ruby_symbol)?;

        // Extract component options
        let component_options = Self::extract_component_options(ruby, &kwargs)?;

        // Validate: style options and component options are mutually exclusive
        let has_style_options = date_style.is_some() || time_style.is_some();
        let has_component_options = !component_options.is_empty();

        if has_style_options && has_component_options {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "cannot use date_style/time_style together with component options (year, month, day, etc.)",
            ));
        }

        // Apply default component options if no options specified
        // Default: year: :numeric, month: :numeric, day: :numeric
        // This matches JavaScript Intl.DateTimeFormat default behavior
        let component_options = if !has_style_options && !has_component_options {
            ComponentOptions {
                year: Some(YearStyle::Numeric),
                month: Some(MonthStyle::Numeric),
                day: Some(DayStyle::Numeric),
                ..Default::default()
            }
        } else {
            component_options
        };
        let has_component_options = !component_options.is_empty();

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
        let calendar =
            helpers::extract_symbol(ruby, &kwargs, "calendar", Calendar::from_ruby_symbol)?;

        // Extract hour_cycle option
        let hour_cycle =
            helpers::extract_symbol(ruby, &kwargs, "hour_cycle", HourCycle::from_ruby_symbol)?;

        // Extract hour12 option and convert to hour_cycle if hour_cycle is not specified
        // hour12: true → :h12, hour12: false → :h23
        let hour12: Option<bool> = kwargs.lookup::<_, Option<bool>>(ruby.to_symbol("hour12"))?;
        let hour_cycle = match (hour_cycle, hour12) {
            (Some(hc), _) => Some(hc), // hour_cycle takes precedence
            (None, Some(true)) => Some(HourCycle::H12),
            (None, Some(false)) => Some(HourCycle::H23),
            (None, None) => None,
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

        // Create field set based on options
        let field_set = if has_component_options {
            Self::create_field_set_from_components(ruby, &component_options)?
        } else {
            Self::create_field_set_from_style(date_style, time_style)
        };

        // Create formatter with calendar and hour_cycle preferences
        let mut prefs: DateTimeFormatterPreferences = (&icu_locale).into();
        if let Some(cal) = calendar {
            prefs.calendar_algorithm = Some(cal.to_calendar_algorithm());
        }
        if let Some(hc) = hour_cycle {
            prefs.hour_cycle = Some(hc.to_icu_hour_cycle());
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
            hour_cycle,
            component_options: if has_component_options {
                Some(component_options)
            } else {
                None
            },
        })
    }

    /// Extract component options from kwargs
    fn extract_component_options(ruby: &Ruby, kwargs: &RHash) -> Result<ComponentOptions, Error> {
        let year = helpers::extract_symbol(ruby, kwargs, "year", YearStyle::from_ruby_symbol)?;
        let month = helpers::extract_symbol(ruby, kwargs, "month", MonthStyle::from_ruby_symbol)?;
        let day = helpers::extract_symbol(ruby, kwargs, "day", DayStyle::from_ruby_symbol)?;
        let weekday =
            helpers::extract_symbol(ruby, kwargs, "weekday", WeekdayStyle::from_ruby_symbol)?;
        let hour = helpers::extract_symbol(ruby, kwargs, "hour", HourStyle::from_ruby_symbol)?;
        let minute =
            helpers::extract_symbol(ruby, kwargs, "minute", MinuteStyle::from_ruby_symbol)?;
        let second =
            helpers::extract_symbol(ruby, kwargs, "second", SecondStyle::from_ruby_symbol)?;

        Ok(ComponentOptions {
            year,
            month,
            day,
            weekday,
            hour,
            minute,
            second,
        })
    }

    /// Create field set from component options
    ///
    /// Maps component combinations to appropriate ICU4X Field Sets.
    /// Field Sets determine which components appear; the locale determines their order.
    /// The length is determined by the component option values (e.g., :long → Long).
    fn create_field_set_from_components(
        ruby: &Ruby,
        opts: &ComponentOptions,
    ) -> Result<CompositeDateTimeFieldSet, Error> {
        let has_date = opts.has_date_components();
        let has_time = opts.has_time_components();
        let length = opts.determine_length();

        match (has_date, has_time) {
            (true, true) => {
                // Date and time components
                Ok(CompositeDateTimeFieldSet::DateTime(
                    DateAndTimeFieldSet::YMDT(fieldsets::YMDT::for_length(length)),
                ))
            }
            (true, false) => {
                // Date only - choose field set based on which components are specified
                let has_year = opts.year.is_some();
                let has_month = opts.month.is_some();
                let has_day = opts.day.is_some();
                let has_weekday = opts.weekday.is_some();

                match (has_year, has_month, has_day, has_weekday) {
                    // Year + Month + Day + Weekday
                    (true, true, true, true) => Ok(CompositeDateTimeFieldSet::Date(
                        DateFieldSet::YMDE(fieldsets::YMDE::for_length(length)),
                    )),
                    // Year + Month + Day
                    (true, true, true, false) => Ok(CompositeDateTimeFieldSet::Date(
                        DateFieldSet::YMD(fieldsets::YMD::for_length(length)),
                    )),
                    // Month + Day + Weekday
                    (false, true, true, true) => Ok(CompositeDateTimeFieldSet::Date(
                        DateFieldSet::MDE(fieldsets::MDE::for_length(length)),
                    )),
                    // Month + Day
                    (false, true, true, false) => Ok(CompositeDateTimeFieldSet::Date(
                        DateFieldSet::MD(fieldsets::MD::for_length(length)),
                    )),
                    // Year + Month (calendar period)
                    (true, true, false, _) => Ok(CompositeDateTimeFieldSet::CalendarPeriod(
                        CalendarPeriodFieldSet::YM(fieldsets::YM::for_length(length)),
                    )),
                    // Month only (calendar period)
                    (false, true, false, _) => Ok(CompositeDateTimeFieldSet::CalendarPeriod(
                        CalendarPeriodFieldSet::M(fieldsets::M::for_length(length)),
                    )),
                    // Day + Weekday
                    (false, false, true, true) => Ok(CompositeDateTimeFieldSet::Date(
                        DateFieldSet::DE(fieldsets::DE::for_length(length)),
                    )),
                    // Day only
                    (false, false, true, false) => Ok(CompositeDateTimeFieldSet::Date(
                        DateFieldSet::D(fieldsets::D::for_length(length)),
                    )),
                    // Weekday only
                    (false, false, false, true) => Ok(CompositeDateTimeFieldSet::Date(
                        DateFieldSet::E(fieldsets::E::for_length(length)),
                    )),
                    // Year only (calendar period)
                    (true, false, false, _) => Ok(CompositeDateTimeFieldSet::CalendarPeriod(
                        CalendarPeriodFieldSet::Y(fieldsets::Y::for_length(length)),
                    )),
                    // Year + Day (not a standard combination, use YMD as fallback)
                    (true, false, true, _) => Ok(CompositeDateTimeFieldSet::Date(
                        DateFieldSet::YMD(fieldsets::YMD::for_length(length)),
                    )),
                    // Should not happen - we checked has_date_components
                    (false, false, false, false) => unreachable!(),
                }
            }
            (false, true) => {
                // Time only - use medium as default since time components are always numeric
                Ok(CompositeDateTimeFieldSet::Time(TimeFieldSet::T(
                    fieldsets::T::for_length(length),
                )))
            }
            (false, false) => Err(Error::new(
                ruby.exception_arg_error(),
                "at least one component option must be specified",
            )),
        }
    }

    /// Create field set based on date_style and time_style
    fn create_field_set_from_style(
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

    /// Format a Ruby Time object or any object responding to #to_time
    ///
    /// # Arguments
    /// * `time` - A Ruby Time object or an object responding to #to_time (e.g., Date, DateTime)
    ///
    /// # Returns
    /// A formatted string
    fn format(&self, time: Value) -> Result<String, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let datetime = self.prepare_datetime(&ruby, time)?;
        let formatted = self.inner.format(&datetime);
        Ok(formatted.to_string())
    }

    /// Format a Ruby Time object and return an array of FormattedPart
    ///
    /// # Arguments
    /// * `time` - A Ruby Time object or an object responding to #to_time (e.g., Date, DateTime)
    ///
    /// # Returns
    /// An array of FormattedPart objects with :type and :value
    fn format_to_parts(&self, time: Value) -> Result<RArray, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let datetime = self.prepare_datetime(&ruby, time)?;

        let formatted = self.inner.format(&datetime);
        let mut collector = PartsCollector::new();
        formatted
            .write_to_parts(&mut collector)
            .map_err(|e| Error::new(ruby.exception_runtime_error(), format!("{}", e)))?;

        parts_to_ruby_array(&ruby, collector, part_to_symbol_name)
    }

    /// Prepare a Ruby Time value for formatting.
    ///
    /// Converts objects responding to #to_time, validates the result,
    /// and converts to ICU4X DateTime.
    fn prepare_datetime(&self, ruby: &Ruby, time: Value) -> Result<DateTime<Gregorian>, Error> {
        // Convert to Time if the object responds to #to_time
        let time_value = if time.respond_to("to_time", false)? {
            time.funcall::<_, _, Value>("to_time", ())?
        } else {
            time
        };

        // Validate that the result is a Time object
        let time_class: Value = ruby.eval("Time")?;
        if !time_value.is_kind_of(magnus::RClass::try_convert(time_class)?) {
            return Err(Error::new(
                ruby.exception_type_error(),
                "argument must be a Time object or respond to #to_time",
            ));
        }

        self.convert_time_to_datetime(ruby, time_value)
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
    /// A hash with :locale, :calendar, :date_style, :time_style, and optionally :time_zone, :hour_cycle
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

        if let Some(hc) = self.hour_cycle {
            hash.aset(
                ruby.to_symbol("hour_cycle"),
                ruby.to_symbol(hc.to_symbol_name()),
            )?;
        }

        // Add component options if they were used
        if let Some(ref opts) = self.component_options {
            if let Some(year) = opts.year {
                hash.aset(
                    ruby.to_symbol("year"),
                    ruby.to_symbol(year.to_symbol_name()),
                )?;
            }
            if let Some(month) = opts.month {
                hash.aset(
                    ruby.to_symbol("month"),
                    ruby.to_symbol(month.to_symbol_name()),
                )?;
            }
            if let Some(day) = opts.day {
                hash.aset(
                    ruby.to_symbol("day"),
                    ruby.to_symbol(day.to_symbol_name()),
                )?;
            }
            if let Some(weekday) = opts.weekday {
                hash.aset(
                    ruby.to_symbol("weekday"),
                    ruby.to_symbol(weekday.to_symbol_name()),
                )?;
            }
            if let Some(hour) = opts.hour {
                hash.aset(
                    ruby.to_symbol("hour"),
                    ruby.to_symbol(hour.to_symbol_name()),
                )?;
            }
            if let Some(minute) = opts.minute {
                hash.aset(
                    ruby.to_symbol("minute"),
                    ruby.to_symbol(minute.to_symbol_name()),
                )?;
            }
            if let Some(second) = opts.second {
                hash.aset(
                    ruby.to_symbol("second"),
                    ruby.to_symbol(second.to_symbol_name()),
                )?;
            }
        }

        Ok(hash)
    }
}

pub fn init(ruby: &Ruby, module: &RModule) -> Result<(), Error> {
    let class = module.define_class("DateTimeFormat", ruby.class_object())?;
    class.define_singleton_method("new", function!(DateTimeFormat::new, -1))?;
    class.define_method("format", method!(DateTimeFormat::format, 1))?;
    class.define_method(
        "format_to_parts",
        method!(DateTimeFormat::format_to_parts, 1),
    )?;
    class.define_method(
        "resolved_options",
        method!(DateTimeFormat::resolved_options, 0),
    )?;
    Ok(())
}
