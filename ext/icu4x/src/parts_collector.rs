use magnus::{Error, RArray, Ruby, Value, prelude::*};
use std::fmt;
use writeable::{Part, PartsWrite};

/// A collector for formatted parts that handles nested part annotations.
///
/// ICU4X uses nested parts - e.g., datetime/day wraps decimal/integer.
/// We track a stack of parts and prefer the outermost (top-level) annotations.
pub struct PartsCollector {
    parts: Vec<(String, Part)>,
    current_buffer: String,
    /// Stack of part contexts for handling nested with_part calls
    part_stack: Vec<Part>,
}

impl PartsCollector {
    pub fn new() -> Self {
        Self {
            parts: Vec::new(),
            current_buffer: String::new(),
            part_stack: Vec::new(),
        }
    }

    fn flush(&mut self) {
        // Store any remaining content as "literal"
        if !self.current_buffer.is_empty() {
            self.parts.push((
                std::mem::take(&mut self.current_buffer),
                Part {
                    category: "literal",
                    value: "literal",
                },
            ));
        }
    }

    pub fn into_parts(mut self) -> Vec<(String, Part)> {
        self.flush();
        self.parts
    }
}

impl fmt::Write for PartsCollector {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        self.current_buffer.push_str(s);
        Ok(())
    }
}

impl PartsWrite for PartsCollector {
    type SubPartsWrite = Self;

    fn with_part(
        &mut self,
        part: Part,
        mut f: impl FnMut(&mut Self::SubPartsWrite) -> fmt::Result,
    ) -> fmt::Result {
        // If at top level, store any buffered content as literal before entering new part
        if self.part_stack.is_empty() && !self.current_buffer.is_empty() {
            self.parts.push((
                std::mem::take(&mut self.current_buffer),
                Part {
                    category: "literal",
                    value: "literal",
                },
            ));
        }

        // Push this part onto the stack
        self.part_stack.push(part);

        // Execute the writing function
        f(self)?;

        // Pop this part from the stack
        self.part_stack.pop();

        // If back at top level, store collected content with effective part
        if self.part_stack.is_empty() && !self.current_buffer.is_empty() {
            self.parts
                .push((std::mem::take(&mut self.current_buffer), part));
        }

        Ok(())
    }
}

/// Converts collected parts to a Ruby array of FormattedPart objects.
///
/// # Arguments
/// * `ruby` - The Ruby runtime reference
/// * `collector` - The PartsCollector with collected parts
/// * `part_mapper` - Function to convert a Part to a symbol name string
///
/// # Returns
/// A Ruby array containing FormattedPart objects.
pub fn parts_to_ruby_array<F>(
    ruby: &Ruby,
    collector: PartsCollector,
    part_mapper: F,
) -> Result<RArray, Error>
where
    F: Fn(&Part) -> &'static str,
{
    let formatted_part_class: Value = ruby.eval("ICU4X::FormattedPart")?;
    let result = ruby.ary_new();

    for (value, part) in collector.into_parts() {
        let symbol_name = part_mapper(&part);
        let part_obj: Value =
            formatted_part_class.funcall("[]", (ruby.to_symbol(symbol_name), value.as_str()))?;
        result.push(part_obj)?;
    }

    Ok(result)
}
