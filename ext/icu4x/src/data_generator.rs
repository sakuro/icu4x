use crate::helpers;
use icu_provider::DataMarkerInfo;
use icu_provider_blob::export::BlobExporter;
use icu_provider_export::prelude::*;
use icu_provider_source::{CoverageLevel, SourceDataProvider};
use magnus::{
    Error, RArray, RClass, RHash, RModule, Ruby, Symbol, Value, function, prelude::*,
    value::ReprValue,
};
use std::collections::HashMap;
use std::fs::File;
use std::io::BufWriter;
use std::path::PathBuf;
use std::sync::OnceLock;

/// Returns a static lookup table mapping marker names to DataMarkerInfo
fn marker_lookup() -> &'static HashMap<&'static str, DataMarkerInfo> {
    static LOOKUP: OnceLock<HashMap<&'static str, DataMarkerInfo>> = OnceLock::new();
    LOOKUP.get_or_init(|| {
        let mut map = HashMap::new();
        macro_rules! cb {
            ($($marker_ty:ty:$marker:ident,)+ #[experimental] $($emarker_ty:ty:$emarker:ident,)+) => {
                $(
                    // Add both the full type name and the short marker name
                    map.insert(stringify!($marker_ty), <$marker_ty>::INFO);
                    map.insert(stringify!($marker), <$marker_ty>::INFO);
                )+
                // Also include experimental markers
                $(
                    map.insert(stringify!($emarker_ty), <$emarker_ty>::INFO);
                    map.insert(stringify!($emarker), <$emarker_ty>::INFO);
                )+
            };
        }
        icu_provider_registry::registry!(cb);
        map
    })
}

/// Ruby wrapper for ICU4X data generation functionality
pub struct DataGenerator;

impl DataGenerator {
    /// Export ICU4X data to a blob file
    ///
    /// # Arguments
    /// * `locales` - Symbol (:full, :recommended, :modern, :moderate, :basic) or Array of locale strings
    /// * `markers` - :all or Array of marker symbols (e.g., [:datetime, :number, :plurals])
    /// * `format` - :blob (only blob format is supported)
    /// * `output` - Pathname for the output file
    fn export(ruby: &Ruby, kwargs: RHash) -> Result<(), Error> {
        // Create the source data provider early (needed for coverage level locales)
        let source_provider = SourceDataProvider::new();

        // Extract locales - can be a Symbol or Array<String>
        let locales_value: Value = kwargs
            .fetch::<_, Value>(ruby.to_symbol("locales"))
            .map_err(|_| {
                Error::new(
                    ruby.exception_arg_error(),
                    "missing required keyword argument: locales",
                )
            })?;

        let locale_families = Self::parse_locales(ruby, locales_value, &source_provider)?;

        // Extract markers
        let markers_value: Value = kwargs
            .fetch::<_, Value>(ruby.to_symbol("markers"))
            .map_err(|_| {
                Error::new(
                    ruby.exception_arg_error(),
                    "missing required keyword argument: markers",
                )
            })?;

        // Parse markers: either :all or an array of marker name strings
        let selected_markers: Option<Vec<DataMarkerInfo>> = {
            let all_symbol = ruby.to_symbol("all");
            if markers_value.eql(all_symbol)? {
                // :all - use all available markers (None means don't filter)
                None
            } else if let Ok(markers_array) = RArray::try_convert(markers_value) {
                // Array of marker name strings
                let lookup = marker_lookup();
                let mut result = Vec::new();
                for i in 0..markers_array.len() {
                    let marker_name: String = markers_array.entry(i as isize)?;
                    match lookup.get(marker_name.as_str()) {
                        Some(&info) => result.push(info),
                        None => {
                            return Err(Error::new(
                                ruby.exception_arg_error(),
                                format!(
                                    "unknown marker: '{}'. Use DataGenerator.available_markers to see valid names.",
                                    marker_name
                                ),
                            ));
                        }
                    }
                }
                Some(result)
            } else {
                return Err(Error::new(
                    ruby.exception_arg_error(),
                    "markers must be :all or an Array of marker name strings",
                ));
            }
        };

        // Extract format
        let format_value: Symbol = kwargs
            .fetch::<_, Symbol>(ruby.to_symbol("format"))
            .map_err(|_| {
                Error::new(
                    ruby.exception_arg_error(),
                    "missing required keyword argument: format",
                )
            })?;

        let blob_symbol = ruby.to_symbol("blob");
        if !format_value.eql(blob_symbol)? {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "only :blob format is currently supported",
            ));
        }

        // Extract output path (must be Pathname)
        let output_value: Value =
            kwargs
                .fetch::<_, Value>(ruby.to_symbol("output"))
                .map_err(|_| {
                    Error::new(
                        ruby.exception_arg_error(),
                        "missing required keyword argument: output",
                    )
                })?;

        let pathname_class: RClass = ruby.eval("Pathname")?;
        if !output_value.is_kind_of(pathname_class) {
            let path_class = output_value.class();
            let class_name = unsafe { path_class.name() }.into_owned();
            return Err(Error::new(
                ruby.exception_type_error(),
                format!("output must be a Pathname, got {}", class_name),
            ));
        }

        let output_str: String = output_value.funcall("to_s", ())?;
        let output_path = PathBuf::from(&output_str);

        // Create parent directories if needed
        if let Some(parent) = output_path.parent() {
            std::fs::create_dir_all(parent).map_err(|e| {
                Error::new(
                    ruby.exception_io_error(),
                    format!("Failed to create output directory: {}", e),
                )
            })?;
        }

        // Create the blob exporter
        let file = File::create(&output_path).map_err(|e| {
            Error::new(
                ruby.exception_io_error(),
                format!("Failed to create output file '{}': {}", output_str, e),
            )
        })?;
        let sink = BufWriter::new(file);

        // Create the export driver
        let driver = ExportDriver::new(
            locale_families,
            DeduplicationStrategy::Maximal.into(),
            LocaleFallbacker::new_without_data(),
        );

        // Apply marker filter if specific markers were requested
        let driver = match selected_markers {
            Some(markers) => driver.with_markers(markers),
            None => driver, // :all - export all markers
        };

        let exporter = BlobExporter::new_with_sink(Box::new(sink));

        driver.export(&source_provider, exporter).map_err(|e| {
            let error_class = helpers::get_exception_class(ruby, "ICU4X::DataGeneratorError");
            Error::new(error_class, format!("Data export failed: {}", e))
        })?;

        Ok(())
    }

    /// Returns an array of available marker names
    fn available_markers(ruby: &Ruby) -> Result<RArray, Error> {
        let lookup = marker_lookup();
        let array = ruby.ary_new();
        // Collect unique marker names (short names only, not full type paths)
        let mut names: Vec<&str> = lookup
            .keys()
            .filter(|k| !k.contains("::"))
            .copied()
            .collect();
        names.sort();
        for name in names {
            array.push(ruby.str_new(name))?;
        }
        Ok(array)
    }

    /// Parse locales from Ruby value (Symbol or Array)
    fn parse_locales(
        ruby: &Ruby,
        locales_value: Value,
        source_provider: &SourceDataProvider,
    ) -> Result<Vec<DataLocaleFamily>, Error> {
        // Check if it's a symbol
        if let Ok(symbol) = Symbol::try_convert(locales_value) {
            let symbol_name = symbol.name()?;
            match symbol_name.as_ref() {
                "full" => Ok(vec![DataLocaleFamily::FULL]),
                "modern" => Self::locales_from_coverage(ruby, source_provider, &[CoverageLevel::Modern]),
                "moderate" => {
                    Self::locales_from_coverage(ruby, source_provider, &[CoverageLevel::Moderate])
                }
                "basic" => Self::locales_from_coverage(ruby, source_provider, &[CoverageLevel::Basic]),
                "recommended" => Self::locales_from_coverage(
                    ruby,
                    source_provider,
                    &[
                        CoverageLevel::Modern,
                        CoverageLevel::Moderate,
                        CoverageLevel::Basic,
                    ],
                ),
                name => Err(Error::new(
                    ruby.exception_arg_error(),
                    format!(
                        "unknown locale specifier: :{}. Valid options are :full, :recommended, :modern, :moderate, :basic",
                        name
                    ),
                )),
            }
        } else if let Ok(array) = RArray::try_convert(locales_value) {
            // Array of locale strings
            let mut families = Vec::new();
            for i in 0..array.len() {
                let locale_str: String = array.entry(i as isize)?;
                let family = DataLocaleFamily::with_descendants(locale_str.parse().map_err(|e| {
                    Error::new(
                        ruby.exception_arg_error(),
                        format!("Invalid locale '{}': {}", locale_str, e),
                    )
                })?);
                families.push(family);
            }
            Ok(families)
        } else {
            Err(Error::new(
                ruby.exception_arg_error(),
                "locales must be a Symbol (:full, :recommended, :modern, :moderate, :basic) or an Array of locale strings",
            ))
        }
    }

    /// Get locales from CLDR coverage levels
    fn locales_from_coverage(
        ruby: &Ruby,
        source_provider: &SourceDataProvider,
        levels: &[CoverageLevel],
    ) -> Result<Vec<DataLocaleFamily>, Error> {
        let locales = source_provider
            .locales_for_coverage_levels(levels.iter().copied())
            .map_err(|e| {
                let error_class = helpers::get_exception_class(ruby, "ICU4X::DataGeneratorError");
                Error::new(
                    error_class,
                    format!("Failed to get locales for coverage levels: {}", e),
                )
            })?;

        Ok(locales
            .into_iter()
            .map(DataLocaleFamily::with_descendants)
            .collect())
    }
}

pub fn init(ruby: &Ruby, module: &RModule) -> Result<(), Error> {
    let class = module.define_class("DataGenerator", ruby.class_object())?;
    class.define_singleton_method("export", function!(DataGenerator::export, 1))?;
    class.define_singleton_method(
        "available_markers",
        function!(DataGenerator::available_markers, 0),
    )?;
    Ok(())
}
