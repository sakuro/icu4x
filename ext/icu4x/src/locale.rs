use magnus::{function, method, prelude::*, Error, RHash, RModule, Ruby};
use icu_locale::Locale as IcuLocale;
use std::cell::RefCell;

/// Ruby wrapper for ICU4X Locale
#[magnus::wrap(class = "ICU4X::Locale", free_immediately, size)]
pub struct Locale {
    pub(crate) inner: RefCell<IcuLocale>,
}

impl Locale {
    /// Parse a BCP 47 locale string
    fn parse(ruby: &Ruby, s: String) -> Result<Self, Error> {
        let locale: IcuLocale = s.parse().map_err(|e| {
            Error::new(
                ruby.exception_arg_error(),
                format!("Invalid locale: {e}"),
            )
        })?;
        Ok(Self {
            inner: RefCell::new(locale),
        })
    }

    /// Get the language component
    fn language(&self) -> Option<String> {
        let locale = self.inner.borrow();
        let lang = locale.id.language;
        if lang.is_unknown() {
            None
        } else {
            Some(lang.to_string())
        }
    }

    /// Get the script component
    fn script(&self) -> Option<String> {
        let locale = self.inner.borrow();
        locale.id.script.map(|s| s.to_string())
    }

    /// Get the region component
    fn region(&self) -> Option<String> {
        let locale = self.inner.borrow();
        locale.id.region.map(|r| r.to_string())
    }

    /// Get extensions as a Hash
    /// Returns { unicode: { "ca" => "japanese", ... }, transform: "...", private: [...] }
    fn extensions(&self) -> RHash {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let result = ruby.hash_new();
        let locale = self.inner.borrow();

        // Unicode extensions
        let unicode_hash = ruby.hash_new();
        for (key, value) in locale.extensions.unicode.keywords.iter() {
            let _ = unicode_hash.aset(key.to_string(), value.to_string());
        }
        let _ = result.aset(ruby.to_symbol("unicode"), unicode_hash);

        // Transform extensions (as string if present)
        let transform_str = locale.extensions.transform.to_string();
        let _ = result.aset(
            ruby.to_symbol("transform"),
            if transform_str.is_empty() {
                None::<String>
            } else {
                Some(transform_str)
            },
        );

        // Private use extensions
        let private_array: Vec<String> = locale
            .extensions
            .private
            .iter()
            .map(|s| s.to_string())
            .collect();
        let _ = result.aset(ruby.to_symbol("private"), private_array);

        result
    }

    /// String representation
    fn to_s(&self) -> String {
        self.inner.borrow().to_string()
    }

    /// Equality comparison
    fn eq(&self, other: &Locale) -> bool {
        *self.inner.borrow() == *other.inner.borrow()
    }
}

pub fn init(ruby: &Ruby, module: &RModule) -> Result<(), Error> {
    let class = module.define_class("Locale", ruby.class_object())?;
    class.define_singleton_method("parse", function!(Locale::parse, 1))?;
    class.define_method("language", method!(Locale::language, 0))?;
    class.define_method("script", method!(Locale::script, 0))?;
    class.define_method("region", method!(Locale::region, 0))?;
    class.define_method("extensions", method!(Locale::extensions, 0))?;
    class.define_method("to_s", method!(Locale::to_s, 0))?;
    class.define_method("==", method!(Locale::eq, 1))?;
    Ok(())
}
