mod collator;
mod data_generator;
mod data_provider;
mod datetime_format;
mod display_names;
mod duration_format;
mod list_format;
mod locale;
mod number_format;
mod plural_rules;
mod segmenter;

use magnus::{Error, Ruby};

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("ICU4X")?;

    locale::init(ruby, &module)?;
    data_provider::init(ruby, &module)?;
    data_generator::init(ruby, &module)?;
    plural_rules::init(ruby, &module)?;
    number_format::init(ruby, &module)?;
    datetime_format::init(ruby, &module)?;
    duration_format::init(ruby, &module)?;
    list_format::init(ruby, &module)?;
    collator::init(ruby, &module)?;
    display_names::init(ruby, &module)?;
    segmenter::init(ruby, &module)?;

    Ok(())
}
