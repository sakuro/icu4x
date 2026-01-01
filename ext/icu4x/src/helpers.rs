use crate::locale::Locale;
use icu_locale::Locale as IcuLocale;
use magnus::{Error, RHash, RModule, Ruby, TryConvert, Value, prelude::*};

/// Resolves the provider from kwargs or falls back to the default provider.
///
/// If an explicit provider is given in kwargs, it is returned.
/// Otherwise, calls `ICU4X.default_provider` to get the default.
/// Returns an error if no provider is available.
pub fn resolve_provider(ruby: &Ruby, kwargs: &RHash) -> Result<Value, Error> {
    let provider_value: Option<Value> =
        kwargs.lookup::<_, Option<Value>>(ruby.to_symbol("provider"))?;

    match provider_value {
        Some(v) if !v.is_nil() => Ok(v),
        _ => {
            let icu4x_module: RModule = ruby.eval("ICU4X")?;
            let default: Value = icu4x_module.funcall("default_provider", ())?;
            if default.is_nil() {
                return Err(Error::new(
                    ruby.exception_arg_error(),
                    "No provider specified and no default configured. Set ICU4X_DATA_PATH environment variable or use ICU4X.configure.",
                ));
            }
            Ok(default)
        }
    }
}

/// Extracts and validates the locale from variadic arguments.
///
/// # Arguments
/// * `ruby` - The Ruby runtime reference
/// * `args` - The variadic arguments passed to the Ruby method
///
/// # Returns
/// A tuple of (IcuLocale, String) where String is the locale's string representation.
///
/// # Errors
/// Returns an error if no arguments are provided or if the first argument
/// is not a valid Locale.
pub fn extract_locale(ruby: &Ruby, args: &[Value]) -> Result<(IcuLocale, String), Error> {
    if args.is_empty() {
        return Err(Error::new(
            ruby.exception_arg_error(),
            "wrong number of arguments (given 0, expected 1+)",
        ));
    }
    let locale: &Locale = TryConvert::try_convert(args[0])?;
    let locale_ref = locale.inner.borrow();
    let locale_str = locale_ref.to_string();
    let icu_locale = locale_ref.clone();
    drop(locale_ref);
    Ok((icu_locale, locale_str))
}
