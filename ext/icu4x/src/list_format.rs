use crate::data_provider::DataProvider;
use crate::helpers;
use crate::parts_collector::{PartsCollector, parts_to_ruby_array};
use icu::list::parts as list_parts;
use icu::list::ListFormatter;
use icu::list::options::{ListFormatterOptions, ListLength};
use icu_provider::buf::AsDeserializingBufferProvider;
use icu4x_macros::RubySymbol;
use magnus::{Error, RArray, RHash, RModule, Ruby, TryConvert, Value, function, method, prelude::*};
use writeable::{Part, Writeable};

/// The type of list formatting
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
enum ListType {
    Conjunction,
    Disjunction,
    Unit,
}

/// The style of list formatting
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
enum ListStyle {
    Long,
    Short,
    Narrow,
}

impl ListStyle {
    fn to_list_length(self) -> ListLength {
        match self {
            ListStyle::Long => ListLength::Wide,
            ListStyle::Short => ListLength::Short,
            ListStyle::Narrow => ListLength::Narrow,
        }
    }
}

/// Convert ICU4X list Part to Ruby symbol name
fn part_to_symbol_name(part: &Part) -> &'static str {
    if *part == list_parts::ELEMENT {
        "element"
    } else if *part == list_parts::LITERAL {
        "literal"
    } else {
        "literal"
    }
}

/// Ruby wrapper for ICU4X ListFormatter
#[magnus::wrap(class = "ICU4X::ListFormat", free_immediately, size)]
pub struct ListFormat {
    inner: ListFormatter,
    locale_str: String,
    list_type: ListType,
    list_style: ListStyle,
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
unsafe impl Send for ListFormat {}

impl ListFormat {
    /// Create a new ListFormat instance
    ///
    /// # Arguments
    /// * `locale` - A Locale instance
    /// * `provider:` - A DataProvider instance
    /// * `type:` - :conjunction (default), :disjunction, or :unit
    /// * `style:` - :long (default), :short, or :narrow
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

        // Extract type option (default: :conjunction)
        let list_type = helpers::extract_symbol(ruby, &kwargs, "type", ListType::from_ruby_symbol)?
            .unwrap_or(ListType::Conjunction);

        // Extract style option (default: :long)
        let list_style =
            helpers::extract_symbol(ruby, &kwargs, "style", ListStyle::from_ruby_symbol)?
                .unwrap_or(ListStyle::Long);

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
        let options = ListFormatterOptions::default().with_length(list_style.to_list_length());

        // Create formatter based on type
        let prefs = (&icu_locale).into();
        let formatter = match list_type {
            ListType::Conjunction => {
                ListFormatter::try_new_and_unstable(&dp.inner.as_deserializing(), prefs, options)
            }
            ListType::Disjunction => {
                ListFormatter::try_new_or_unstable(&dp.inner.as_deserializing(), prefs, options)
            }
            ListType::Unit => {
                ListFormatter::try_new_unit_unstable(&dp.inner.as_deserializing(), prefs, options)
            }
        }
        .map_err(|e| Error::new(error_class, format!("Failed to create ListFormat: {}", e)))?;

        Ok(Self {
            inner: formatter,
            locale_str,
            list_type,
            list_style,
        })
    }

    /// Format a list of strings
    ///
    /// # Arguments
    /// * `list` - An array of strings
    ///
    /// # Returns
    /// A formatted string
    fn format(&self, list: Value) -> Result<String, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let items = self.prepare_list(&ruby, list)?;
        let formatted = self.inner.format(items.iter().map(|s| s.as_str()));
        Ok(formatted.to_string())
    }

    /// Format a list of strings and return an array of FormattedPart
    ///
    /// # Arguments
    /// * `list` - An array of strings
    ///
    /// # Returns
    /// An array of FormattedPart objects with :type and :value
    fn format_to_parts(&self, list: Value) -> Result<RArray, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let items = self.prepare_list(&ruby, list)?;

        let formatted = self.inner.format(items.iter().map(|s| s.as_str()));
        let mut collector = PartsCollector::new();
        formatted
            .write_to_parts(&mut collector)
            .map_err(|e| Error::new(ruby.exception_runtime_error(), format!("{}", e)))?;

        parts_to_ruby_array(&ruby, collector, part_to_symbol_name)
    }

    /// Prepare a Ruby list for formatting.
    ///
    /// Converts Ruby Array to Vec<String>.
    fn prepare_list(&self, ruby: &Ruby, list: Value) -> Result<Vec<String>, Error> {
        let array: RArray = TryConvert::try_convert(list)
            .map_err(|_| Error::new(ruby.exception_type_error(), "list must be an Array"))?;

        array
            .into_iter()
            .map(TryConvert::try_convert)
            .collect::<Result<Vec<_>, _>>()
    }

    /// Get the resolved options
    ///
    /// # Returns
    /// A hash with :locale, :type, and :style keys
    fn resolved_options(&self) -> Result<RHash, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let hash = ruby.hash_new();
        hash.aset(ruby.to_symbol("locale"), self.locale_str.as_str())?;
        hash.aset(
            ruby.to_symbol("type"),
            ruby.to_symbol(self.list_type.to_symbol_name()),
        )?;
        hash.aset(
            ruby.to_symbol("style"),
            ruby.to_symbol(self.list_style.to_symbol_name()),
        )?;
        Ok(hash)
    }
}

pub fn init(ruby: &Ruby, module: &RModule) -> Result<(), Error> {
    let class = module.define_class("ListFormat", ruby.class_object())?;
    class.define_singleton_method("new", function!(ListFormat::new, -1))?;
    class.define_method("format", method!(ListFormat::format, 1))?;
    class.define_method("format_to_parts", method!(ListFormat::format_to_parts, 1))?;
    class.define_method("resolved_options", method!(ListFormat::resolved_options, 0))?;
    Ok(())
}
