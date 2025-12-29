mod data_generator;
mod data_provider;
mod locale;
mod number_format;
mod plural_rules;

use magnus::{Error, Ruby};

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("ICU4X")?;

    locale::init(ruby, &module)?;
    data_provider::init(ruby, &module)?;
    data_generator::init(ruby, &module)?;
    plural_rules::init(ruby, &module)?;
    number_format::init(ruby, &module)?;

    Ok(())
}
