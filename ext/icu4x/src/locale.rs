use crate::helpers;
use icu_locale::{Locale as IcuLocale, LocaleExpander, TransformResult};
use magnus::{Error, RHash, RModule, Ruby, function, method, prelude::*, typed_data::Obj};
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
                helpers::get_exception_class(ruby, "ICU4X::LocaleError"),
                format!("Invalid locale: {e}"),
            )
        })?;
        Ok(Self {
            inner: RefCell::new(locale),
        })
    }

    /// Parse a POSIX locale string (e.g., "ja_JP.UTF-8")
    ///
    /// Converts POSIX locale format to BCP 47 format:
    /// - `ja_JP.UTF-8` -> `ja-JP` (codeset ignored)
    /// - `C` or `POSIX` -> `und` (undetermined)
    /// - `sr_RS@latin` -> `sr-Latn-RS` (@latin/@cyrillic converted to script)
    fn parse_posix(ruby: &Ruby, posix_str: String) -> Result<Self, Error> {
        // Handle special cases
        if posix_str == "C" || posix_str == "POSIX" {
            return Self::parse(ruby, "und".to_string());
        }

        // Handle empty string
        if posix_str.is_empty() {
            return Err(Error::new(
                helpers::get_exception_class(ruby, "ICU4X::LocaleError"),
                "Invalid POSIX locale: empty string",
            ));
        }

        // Parse POSIX format: language[_territory][.codeset][@modifier]
        let mut input = posix_str.as_str();

        // Extract modifier (@...)
        let modifier = if let Some(pos) = input.find('@') {
            let m = &input[pos + 1..];
            input = &input[..pos];
            Some(m)
        } else {
            None
        };

        // Remove codeset (....)
        if let Some(pos) = input.find('.') {
            input = &input[..pos];
        }

        // Parse language_territory
        let parts: Vec<&str> = input.split('_').collect();
        let language = match parts.first() {
            Some(lang) if !lang.is_empty() => *lang,
            _ => {
                return Err(Error::new(
                    helpers::get_exception_class(ruby, "ICU4X::LocaleError"),
                    format!("Invalid POSIX locale: {}", posix_str),
                ));
            }
        };
        let territory = parts.get(1).filter(|t| !t.is_empty());

        // Build BCP 47 string
        let mut bcp47 = language.to_lowercase();

        // Handle script from modifier
        if let Some(m) = modifier {
            match m.to_lowercase().as_str() {
                "latin" => bcp47.push_str("-Latn"),
                "cyrillic" => bcp47.push_str("-Cyrl"),
                _ => {} // Other modifiers are ignored
            }
        }

        if let Some(t) = territory {
            bcp47.push('-');
            bcp47.push_str(&t.to_uppercase());
        }

        Self::parse(ruby, bcp47)
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

    /// Maximize the locale in place (Add Likely Subtags algorithm, UTS #35)
    /// Returns self if modified, nil if unchanged
    fn maximize_bang(rb_self: Obj<Self>) -> Option<Obj<Self>> {
        let expander = LocaleExpander::new_common();
        let mut locale = rb_self.inner.borrow_mut();
        match expander.maximize(&mut locale.id) {
            TransformResult::Modified => Some(rb_self),
            TransformResult::Unmodified => None,
        }
    }

    /// Maximize the locale, returning a new Locale object
    fn maximize(&self) -> Self {
        let expander = LocaleExpander::new_common();
        let mut new_id = self.inner.borrow().id.clone();
        expander.maximize(&mut new_id);
        Self {
            inner: RefCell::new(IcuLocale::from(new_id)),
        }
    }

    /// Minimize the locale in place (Remove Likely Subtags algorithm, UTS #35)
    /// Returns self if modified, nil if unchanged
    fn minimize_bang(rb_self: Obj<Self>) -> Option<Obj<Self>> {
        let expander = LocaleExpander::new_common();
        let mut locale = rb_self.inner.borrow_mut();
        match expander.minimize(&mut locale.id) {
            TransformResult::Modified => Some(rb_self),
            TransformResult::Unmodified => None,
        }
    }

    /// Minimize the locale, returning a new Locale object
    fn minimize(&self) -> Self {
        let expander = LocaleExpander::new_common();
        let mut new_id = self.inner.borrow().id.clone();
        expander.minimize(&mut new_id);
        Self {
            inner: RefCell::new(IcuLocale::from(new_id)),
        }
    }
}

pub fn init(ruby: &Ruby, module: &RModule) -> Result<(), Error> {
    let class = module.define_class("Locale", ruby.class_object())?;
    class.define_singleton_method("parse", function!(Locale::parse, 1))?;
    class.define_singleton_method("parse_posix", function!(Locale::parse_posix, 1))?;
    class.define_method("language", method!(Locale::language, 0))?;
    class.define_method("script", method!(Locale::script, 0))?;
    class.define_method("region", method!(Locale::region, 0))?;
    class.define_method("extensions", method!(Locale::extensions, 0))?;
    class.define_method("to_s", method!(Locale::to_s, 0))?;
    class.define_method("==", method!(Locale::eq, 1))?;
    class.define_method("maximize!", method!(Locale::maximize_bang, 0))?;
    class.define_method("maximize", method!(Locale::maximize, 0))?;
    class.define_method("minimize!", method!(Locale::minimize_bang, 0))?;
    class.define_method("minimize", method!(Locale::minimize, 0))?;
    Ok(())
}
