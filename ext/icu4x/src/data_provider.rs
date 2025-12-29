use icu_provider_blob::BlobDataProvider;
use magnus::{function, prelude::*, value::ReprValue, Error, ExceptionClass, RClass, RModule, Ruby, Value};
use std::cell::RefCell;
use std::fs;
use std::path::PathBuf;

/// Ruby wrapper for ICU4X BlobDataProvider
///
/// Uses RefCell for interior mutability since magnus doesn't support &mut references.
///
/// # Safety
/// We manually implement Send because:
/// 1. Ruby's GVL (Global VM Lock) ensures only one thread executes Ruby code at a time
/// 2. The BlobDataProvider is only accessed through Ruby method calls
/// 3. We never share the provider across threads in Rust code
#[magnus::wrap(class = "ICU4X::DataProvider", free_immediately, size)]
pub struct DataProvider {
    inner: RefCell<Option<BlobDataProvider>>,
}

// SAFETY: Ruby's GVL protects access to this type. The BlobDataProvider is only
// accessed through Ruby method calls, which are serialized by the GVL.
unsafe impl Send for DataProvider {}

impl DataProvider {
    /// Create a DataProvider from a blob file
    /// Only accepts Pathname objects, not String
    fn from_blob(ruby: &Ruby, path: Value) -> Result<Self, Error> {
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
        let provider = BlobDataProvider::try_new_from_static_blob(static_blob).map_err(|e| {
            // Get the DataError exception class
            let data_error_class: ExceptionClass = ruby
                .eval("ICU4X::DataError")
                .unwrap_or_else(|_| ruby.exception_runtime_error());
            Error::new(data_error_class, format!("Failed to create data provider: {}", e))
        })?;

        Ok(Self { inner: RefCell::new(Some(provider)) })
    }

    /// Take the inner BlobDataProvider, leaving None in its place
    /// Can only be called once; subsequent calls will return None
    pub fn take_inner(&self) -> Option<BlobDataProvider> {
        self.inner.borrow_mut().take()
    }
}

pub fn init(ruby: &Ruby, module: &RModule) -> Result<(), Error> {
    let class = module.define_class("DataProvider", ruby.class_object())?;
    class.define_singleton_method("from_blob", function!(DataProvider::from_blob, 1))?;
    Ok(())
}
