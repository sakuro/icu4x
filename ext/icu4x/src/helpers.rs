use magnus::{Error, RHash, RModule, Ruby, Value, prelude::*};

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
