use icu::locale::fallback::LocaleFallbacker;
use icu_provider_adapters::fallback::LocaleFallbackProvider;
use icu_provider_blob::BlobDataProvider;
use magnus::{
    Error, ExceptionClass, RClass, RHash, RModule, Ruby, Symbol, TryConvert, Value, function,
    prelude::*, value::ReprValue,
};
use std::fs;
use std::path::PathBuf;

/// Ruby wrapper for ICU4X DataProvider with locale fallback support
///
/// This provider loads data from a blob file and provides locale fallback
/// automatically. When data for a specific locale is not found, it will
/// fallback through the locale hierarchy (e.g., ja-JP -> ja -> und).
///
/// # Safety
/// We manually implement Send because:
/// 1. Ruby's GVL (Global VM Lock) ensures only one thread executes Ruby code at a time
/// 2. The provider is only accessed through Ruby method calls
/// 3. We never share the provider across threads in Rust code
#[magnus::wrap(class = "ICU4X::DataProvider", free_immediately, size)]
pub struct DataProvider {
    pub(crate) inner: LocaleFallbackProvider<BlobDataProvider>,
}

// SAFETY: Ruby's GVL protects access to this type. The provider is only
// accessed through Ruby method calls, which are serialized by the GVL.
unsafe impl Send for DataProvider {}

impl DataProvider {
    /// Create a DataProvider from a blob file with locale fallback support
    ///
    /// # Arguments
    /// * `path` - A Pathname object pointing to the blob file
    /// * `priority` - Fallback priority (:language or :region), defaults to :language
    ///
    /// # Returns
    /// A new DataProvider instance with locale fallback enabled
    fn from_blob(ruby: &Ruby, args: &[Value]) -> Result<Self, Error> {
        // Parse arguments: (path, **kwargs)
        // args[0] = path (required, Pathname)
        // args[1] = kwargs hash (optional, from Ruby keyword arguments)
        if args.is_empty() {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "wrong number of arguments (given 0, expected 1..2)",
            ));
        }

        let path = args[0];

        // Get the Pathname class
        let pathname_class: RClass = ruby.eval("Pathname")?;

        // Check if the argument is a Pathname instance
        if !path.is_kind_of(pathname_class) {
            let path_class = path.class();
            // SAFETY: We have a valid Ruby Value from the method call
            let class_name = unsafe { path_class.name() }.into_owned();
            return Err(Error::new(
                ruby.exception_type_error(),
                format!("expected Pathname, got {}", class_name),
            ));
        }

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

        // Get the path as a string by calling to_s
        let path_str: String = path.funcall("to_s", ())?;
        let path_buf = PathBuf::from(&path_str);

        // Read the file contents
        let blob_data = fs::read(&path_buf).map_err(|e| {
            Error::new(
                ruby.exception_io_error(),
                format!("Failed to read blob file '{}': {}", path_str, e),
            )
        })?;

        // Leak the blob data to create a 'static reference
        let static_blob: &'static [u8] = Box::leak(blob_data.into_boxed_slice());

        // Create the BlobDataProvider from static blob
        let blob_provider =
            BlobDataProvider::try_new_from_static_blob(static_blob).map_err(|e| {
                // Get the DataError exception class
                let data_error_class: ExceptionClass = ruby
                    .eval("ICU4X::DataError")
                    .unwrap_or_else(|_| ruby.exception_runtime_error());
                Error::new(
                    data_error_class,
                    format!("Failed to create data provider: {}", e),
                )
            })?;

        // Create the LocaleFallbacker with compiled data
        // Use static_to_owned() to get an owned LocaleFallbacker
        let fallbacker = LocaleFallbacker::new().static_to_owned();

        // Create the LocaleFallbackProvider
        // Note: LocaleFallbackConfig is applied when iterating, not at construction
        let inner = LocaleFallbackProvider::new(blob_provider, fallbacker);

        Ok(Self { inner })
    }
}

pub fn init(ruby: &Ruby, module: &RModule) -> Result<(), Error> {
    let class = module.define_class("DataProvider", ruby.class_object())?;
    class.define_singleton_method("from_blob", function!(DataProvider::from_blob, -1))?;
    Ok(())
}
