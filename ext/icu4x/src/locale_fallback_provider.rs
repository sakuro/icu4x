use crate::data_provider::DataProvider;
use icu::locale::fallback::LocaleFallbacker;
use icu_provider_adapters::fallback::LocaleFallbackProvider as IcuLocaleFallbackProvider;
use icu_provider_blob::BlobDataProvider;
use magnus::{function, prelude::*, Error, RHash, RModule, Ruby, Symbol, TryConvert, Value};

/// Ruby wrapper for ICU4X LocaleFallbackProvider
///
/// This provider wraps a BlobDataProvider with locale fallback support.
/// When data for a specific locale is not found, it will fallback through
/// the locale hierarchy (e.g., ja-JP -> ja -> und).
///
/// # Safety
/// We manually implement Send because:
/// 1. Ruby's GVL (Global VM Lock) ensures only one thread executes Ruby code at a time
/// 2. The provider is only accessed through Ruby method calls
/// 3. We never share the provider across threads in Rust code
#[magnus::wrap(class = "ICU4X::LocaleFallbackProvider", free_immediately, size)]
pub struct LocaleFallbackProvider {
    pub(crate) inner: IcuLocaleFallbackProvider<BlobDataProvider>,
}

// SAFETY: Ruby's GVL protects access to this type. The provider is only
// accessed through Ruby method calls, which are serialized by the GVL.
unsafe impl Send for LocaleFallbackProvider {}

impl LocaleFallbackProvider {
    /// Create a LocaleFallbackProvider from a DataProvider
    ///
    /// # Arguments
    /// * `provider` - A DataProvider instance (will be consumed)
    /// * `priority` - Fallback priority (:language or :region), defaults to :language
    fn new(ruby: &Ruby, args: &[Value]) -> Result<Self, Error> {
        // Parse arguments: (provider, **kwargs)
        // args[0] = provider (required)
        // args[1] = kwargs hash (optional, from Ruby keyword arguments)
        if args.is_empty() {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "wrong number of arguments (given 0, expected 1..2)",
            ));
        }

        // Get the provider
        let provider: &DataProvider = TryConvert::try_convert(args[0])?;

        // Get optional kwargs
        let kwargs: Option<RHash> = if args.len() > 1 {
            Some(TryConvert::try_convert(args[1])?)
        } else {
            None
        };

        // Extract priority option (default: :language)
        let priority_value: Option<Symbol> = match kwargs {
            Some(hash) => hash.lookup::<_, Option<Symbol>>(ruby.to_symbol("priority"))?,
            None => None,
        };

        let priority_sym = priority_value.unwrap_or_else(|| ruby.to_symbol("language"));
        let language_sym = ruby.to_symbol("language");
        let region_sym = ruby.to_symbol("region");

        // Validate priority value
        if !priority_sym.equal(language_sym)? && !priority_sym.equal(region_sym)? {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "priority must be :language or :region",
            ));
        }

        // Take the inner BlobDataProvider from the DataProvider
        let blob_provider = provider.take_inner().ok_or_else(|| {
            Error::new(
                ruby.exception_arg_error(),
                "DataProvider has already been consumed",
            )
        })?;

        // Create the LocaleFallbacker with compiled data
        // Use static_to_owned() to get an owned LocaleFallbacker
        let fallbacker = LocaleFallbacker::new().static_to_owned();

        // Create the LocaleFallbackProvider
        // Note: LocaleFallbackConfig is applied when iterating, not at construction
        let inner = IcuLocaleFallbackProvider::new(blob_provider, fallbacker);

        Ok(Self { inner })
    }
}

pub fn init(ruby: &Ruby, module: &RModule) -> Result<(), Error> {
    let class = module.define_class("LocaleFallbackProvider", ruby.class_object())?;
    class.define_singleton_method("new", function!(LocaleFallbackProvider::new, -1))?;
    Ok(())
}
