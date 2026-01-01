use crate::data_provider::DataProvider;
use crate::helpers;
use icu::experimental::displaynames::{
    DisplayNamesOptions, Fallback, LanguageDisplayNames, LocaleDisplayNamesFormatter,
    RegionDisplayNames, ScriptDisplayNames, Style,
};
use icu_locale::LanguageIdentifier;
use icu_provider::buf::AsDeserializingBufferProvider;
use icu4x_macros::FromRubySymbol;
use magnus::{
    Error, ExceptionClass, RHash, RModule, Ruby, Symbol, TryConvert, Value, function, method,
    prelude::*,
};

/// Display name type
#[derive(Clone, Copy, PartialEq, Eq, FromRubySymbol)]
enum DisplayNamesType {
    Language,
    Region,
    Script,
    Locale,
}

impl DisplayNamesType {
    fn to_symbol_name(self) -> &'static str {
        match self {
            DisplayNamesType::Language => "language",
            DisplayNamesType::Region => "region",
            DisplayNamesType::Script => "script",
            DisplayNamesType::Locale => "locale",
        }
    }
}

/// Display name style
#[derive(Clone, Copy, PartialEq, Eq, FromRubySymbol)]
enum DisplayNamesStyle {
    Long,
    Short,
    Narrow,
}

impl DisplayNamesStyle {
    fn to_symbol_name(self) -> &'static str {
        match self {
            DisplayNamesStyle::Long => "long",
            DisplayNamesStyle::Short => "short",
            DisplayNamesStyle::Narrow => "narrow",
        }
    }

    fn to_icu_style(self) -> Style {
        match self {
            DisplayNamesStyle::Long => Style::Long,
            DisplayNamesStyle::Short => Style::Short,
            DisplayNamesStyle::Narrow => Style::Narrow,
        }
    }
}

/// Display name fallback option
#[derive(Clone, Copy, PartialEq, Eq, FromRubySymbol)]
enum DisplayNamesFallback {
    Code,
    None,
}

impl DisplayNamesFallback {
    fn to_symbol_name(self) -> &'static str {
        match self {
            DisplayNamesFallback::Code => "code",
            DisplayNamesFallback::None => "none",
        }
    }

    fn to_icu_fallback(self) -> Fallback {
        match self {
            DisplayNamesFallback::Code => Fallback::Code,
            DisplayNamesFallback::None => Fallback::None,
        }
    }
}

/// Inner formatter enum to hold the different types
enum DisplayNamesFormatter {
    Language(LanguageDisplayNames),
    Region(RegionDisplayNames),
    Script(ScriptDisplayNames),
    Locale(Box<LocaleDisplayNamesFormatter>),
}

/// Ruby wrapper for ICU4X DisplayNames
#[magnus::wrap(class = "ICU4X::DisplayNames", free_immediately, size)]
pub struct DisplayNames {
    inner: DisplayNamesFormatter,
    locale_str: String,
    display_type: DisplayNamesType,
    style: DisplayNamesStyle,
    fallback: DisplayNamesFallback,
}

// SAFETY: Ruby's GVL protects access to this type.
unsafe impl Send for DisplayNames {}

impl DisplayNames {
    /// Create a new DisplayNames instance
    ///
    /// # Arguments
    /// * `locale` - A Locale instance
    /// * `provider:` - A DataProvider instance
    /// * `type:` - :language, :region, :script, or :locale
    /// * `style:` - :long (default), :short, or :narrow
    /// * `fallback:` - :code (default) or :none
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

        // Extract type (required)
        let type_value: Symbol = kwargs
            .lookup::<_, Option<Symbol>>(ruby.to_symbol("type"))?
            .ok_or_else(|| Error::new(ruby.exception_arg_error(), "missing keyword: :type"))?;
        let display_type = DisplayNamesType::from_ruby_symbol(ruby, type_value, "type")?;

        // Extract style option (default: :long)
        let style_value: Option<Symbol> =
            kwargs.lookup::<_, Option<Symbol>>(ruby.to_symbol("style"))?;
        let style = match style_value {
            Some(sym) => DisplayNamesStyle::from_ruby_symbol(ruby, sym, "style")?,
            None => DisplayNamesStyle::Long,
        };

        // Extract fallback option (default: :code)
        let fallback_value: Option<Symbol> =
            kwargs.lookup::<_, Option<Symbol>>(ruby.to_symbol("fallback"))?;
        let fallback = match fallback_value {
            Some(sym) => DisplayNamesFallback::from_ruby_symbol(ruby, sym, "fallback")?,
            None => DisplayNamesFallback::Code,
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

        // Build options
        let mut options = DisplayNamesOptions::default();
        options.style = Some(style.to_icu_style());
        options.fallback = fallback.to_icu_fallback();

        // Create the appropriate formatter based on type
        let inner = match display_type {
            DisplayNamesType::Language => {
                let formatter = LanguageDisplayNames::try_new_unstable(
                    &dp.inner.as_deserializing(),
                    (&icu_locale).into(),
                    options,
                )
                .map_err(|e| {
                    Error::new(
                        error_class,
                        format!("Failed to create LanguageDisplayNames: {}", e),
                    )
                })?;
                DisplayNamesFormatter::Language(formatter)
            }
            DisplayNamesType::Region => {
                let formatter = RegionDisplayNames::try_new_unstable(
                    &dp.inner.as_deserializing(),
                    (&icu_locale).into(),
                    options,
                )
                .map_err(|e| {
                    Error::new(
                        error_class,
                        format!("Failed to create RegionDisplayNames: {}", e),
                    )
                })?;
                DisplayNamesFormatter::Region(formatter)
            }
            DisplayNamesType::Script => {
                let formatter = ScriptDisplayNames::try_new_unstable(
                    &dp.inner.as_deserializing(),
                    (&icu_locale).into(),
                    options,
                )
                .map_err(|e| {
                    Error::new(
                        error_class,
                        format!("Failed to create ScriptDisplayNames: {}", e),
                    )
                })?;
                DisplayNamesFormatter::Script(formatter)
            }
            DisplayNamesType::Locale => {
                let formatter = LocaleDisplayNamesFormatter::try_new_unstable(
                    &dp.inner.as_deserializing(),
                    (&icu_locale).into(),
                    options,
                )
                .map_err(|e| {
                    Error::new(
                        error_class,
                        format!("Failed to create LocaleDisplayNamesFormatter: {}", e),
                    )
                })?;
                DisplayNamesFormatter::Locale(Box::new(formatter))
            }
        };

        Ok(Self {
            inner,
            locale_str,
            display_type,
            style,
            fallback,
        })
    }

    /// Get display name for a code
    ///
    /// # Arguments
    /// * `code` - Language/region/script code, or locale string
    ///
    /// # Returns
    /// Display name, or nil when fallback: :none and not found
    fn of(&self, code: String) -> Result<Option<String>, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");

        let result = match &self.inner {
            DisplayNamesFormatter::Language(formatter) => {
                // Parse the language code
                let lang_id: LanguageIdentifier = code.parse().map_err(|_| {
                    Error::new(
                        ruby.exception_arg_error(),
                        format!("Invalid language code: {}", code),
                    )
                })?;
                formatter.of(lang_id.language).map(|s| s.to_string())
            }
            DisplayNamesFormatter::Region(formatter) => {
                // Parse the region code
                let region: icu_locale::subtags::Region = code.parse().map_err(|_| {
                    Error::new(
                        ruby.exception_arg_error(),
                        format!("Invalid region code: {}", code),
                    )
                })?;
                formatter.of(region).map(|s| s.to_string())
            }
            DisplayNamesFormatter::Script(formatter) => {
                // Parse the script code
                let script: icu_locale::subtags::Script = code.parse().map_err(|_| {
                    Error::new(
                        ruby.exception_arg_error(),
                        format!("Invalid script code: {}", code),
                    )
                })?;
                formatter.of(script).map(|s| s.to_string())
            }
            DisplayNamesFormatter::Locale(formatter) => {
                // Parse the locale
                let locale: icu_locale::Locale = code.parse().map_err(|_| {
                    Error::new(
                        ruby.exception_arg_error(),
                        format!("Invalid locale: {}", code),
                    )
                })?;
                Some(formatter.of(&locale).to_string())
            }
        };

        // Apply fallback behavior
        Ok(match result {
            Some(name) => Some(name),
            None => match self.fallback {
                DisplayNamesFallback::Code => Some(code),
                DisplayNamesFallback::None => None,
            },
        })
    }

    /// Get the resolved options
    ///
    /// # Returns
    /// A hash with :locale, :type, :style, and :fallback keys
    fn resolved_options(&self) -> Result<RHash, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let hash = ruby.hash_new();
        hash.aset(ruby.to_symbol("locale"), self.locale_str.as_str())?;
        hash.aset(
            ruby.to_symbol("type"),
            ruby.to_symbol(self.display_type.to_symbol_name()),
        )?;
        hash.aset(
            ruby.to_symbol("style"),
            ruby.to_symbol(self.style.to_symbol_name()),
        )?;
        hash.aset(
            ruby.to_symbol("fallback"),
            ruby.to_symbol(self.fallback.to_symbol_name()),
        )?;
        Ok(hash)
    }
}

pub fn init(ruby: &Ruby, module: &RModule) -> Result<(), Error> {
    let class = module.define_class("DisplayNames", ruby.class_object())?;
    class.define_singleton_method("new", function!(DisplayNames::new, -1))?;
    class.define_method("of", method!(DisplayNames::of, 1))?;
    class.define_method(
        "resolved_options",
        method!(DisplayNames::resolved_options, 0),
    )?;
    Ok(())
}
