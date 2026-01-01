use crate::data_provider::DataProvider;
use icu::segmenter::options::{LineBreakOptions, SentenceBreakOptions, WordBreakOptions};
use icu::segmenter::{
    GraphemeClusterSegmenter, GraphemeClusterSegmenterBorrowed, LineSegmenter,
    LineSegmenterBorrowed, SentenceSegmenter, SentenceSegmenterBorrowed, WordSegmenter,
    WordSegmenterBorrowed,
};
use icu_provider::buf::AsDeserializingBufferProvider;
use icu4x_macros::RubySymbol;
use magnus::{
    Error, ExceptionClass, RArray, RClass, RHash, RModule, Ruby, Symbol, TryConvert, Value,
    function, method, prelude::*,
};

/// Granularity level for segmentation
#[derive(Clone, Copy, PartialEq, Eq, RubySymbol)]
enum Granularity {
    Grapheme,
    Word,
    Sentence,
    Line,
}

/// Internal segmenter variants - using owned types
enum SegmenterKind {
    GraphemeBorrowed(GraphemeClusterSegmenterBorrowed<'static>),
    GraphemeOwned(GraphemeClusterSegmenter),
    WordBorrowed(WordSegmenterBorrowed<'static>),
    WordOwned(WordSegmenter),
    SentenceOwned(SentenceSegmenter),
    LineOwned(LineSegmenter),
}

/// Ruby wrapper for ICU4X Segmenter
#[magnus::wrap(class = "ICU4X::Segmenter", free_immediately, size)]
pub struct Segmenter {
    inner: SegmenterKind,
    granularity: Granularity,
}

// SAFETY: Ruby's GVL protects access to this type.
unsafe impl Send for Segmenter {}

impl Segmenter {
    /// Create a new Segmenter instance
    ///
    /// # Arguments
    /// * `granularity:` - :grapheme, :word, :sentence, or :line
    /// * `provider:` - A DataProvider instance (optional for :grapheme)
    fn new(ruby: &Ruby, args: &[Value]) -> Result<Self, Error> {
        // Parse arguments: (**kwargs)
        let kwargs: RHash = if !args.is_empty() {
            TryConvert::try_convert(args[0])?
        } else {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "missing keyword: :granularity",
            ));
        };

        // Extract granularity (required)
        let granularity_value: Symbol = kwargs
            .lookup::<_, Option<Symbol>>(ruby.to_symbol("granularity"))?
            .ok_or_else(|| {
                Error::new(ruby.exception_arg_error(), "missing keyword: :granularity")
            })?;
        let granularity = Granularity::from_ruby_symbol(ruby, granularity_value, "granularity")?;

        // Extract provider (optional for grapheme, recommended for others)
        let provider_value: Option<Value> =
            kwargs.lookup::<_, Option<Value>>(ruby.to_symbol("provider"))?;

        // Get the error exception class
        let error_class: ExceptionClass = ruby
            .eval("ICU4X::Error")
            .unwrap_or_else(|_| ruby.exception_runtime_error());

        // Create the appropriate segmenter
        let inner = match granularity {
            Granularity::Grapheme => {
                if let Some(pv) = provider_value {
                    let dp: &DataProvider = TryConvert::try_convert(pv).map_err(|_| {
                        Error::new(
                            ruby.exception_type_error(),
                            "provider must be a DataProvider",
                        )
                    })?;
                    let segmenter =
                        GraphemeClusterSegmenter::try_new_unstable(&dp.inner.as_deserializing())
                            .map_err(|e| {
                                Error::new(
                                    error_class,
                                    format!("Failed to create Segmenter: {}", e),
                                )
                            })?;
                    SegmenterKind::GraphemeOwned(segmenter)
                } else {
                    let segmenter = GraphemeClusterSegmenter::new();
                    SegmenterKind::GraphemeBorrowed(segmenter)
                }
            }
            Granularity::Word => {
                let options = WordBreakOptions::default();
                if let Some(pv) = provider_value {
                    let dp: &DataProvider = TryConvert::try_convert(pv).map_err(|_| {
                        Error::new(
                            ruby.exception_type_error(),
                            "provider must be a DataProvider",
                        )
                    })?;
                    let segmenter =
                        WordSegmenter::try_new_auto_unstable(&dp.inner.as_deserializing(), options)
                            .map_err(|e| {
                                Error::new(
                                    error_class,
                                    format!("Failed to create Segmenter: {}", e),
                                )
                            })?;
                    SegmenterKind::WordOwned(segmenter)
                } else {
                    let segmenter = WordSegmenter::new_auto(Default::default());
                    SegmenterKind::WordBorrowed(segmenter)
                }
            }
            Granularity::Sentence => {
                let options = SentenceBreakOptions::default();
                let dp: &DataProvider = provider_value
                    .ok_or_else(|| {
                        Error::new(
                            ruby.exception_arg_error(),
                            "provider is required for sentence segmentation",
                        )
                    })
                    .and_then(|v| {
                        TryConvert::try_convert(v).map_err(|_| {
                            Error::new(
                                ruby.exception_type_error(),
                                "provider must be a DataProvider",
                            )
                        })
                    })?;

                let segmenter =
                    SentenceSegmenter::try_new_unstable(&dp.inner.as_deserializing(), options)
                        .map_err(|e| {
                            Error::new(error_class, format!("Failed to create Segmenter: {}", e))
                        })?;
                SegmenterKind::SentenceOwned(segmenter)
            }
            Granularity::Line => {
                let options = LineBreakOptions::default();
                let dp: &DataProvider = provider_value
                    .ok_or_else(|| {
                        Error::new(
                            ruby.exception_arg_error(),
                            "provider is required for line segmentation",
                        )
                    })
                    .and_then(|v| {
                        TryConvert::try_convert(v).map_err(|_| {
                            Error::new(
                                ruby.exception_type_error(),
                                "provider must be a DataProvider",
                            )
                        })
                    })?;

                let segmenter =
                    LineSegmenter::try_new_auto_unstable(&dp.inner.as_deserializing(), options)
                        .map_err(|e| {
                            Error::new(error_class, format!("Failed to create Segmenter: {}", e))
                        })?;
                SegmenterKind::LineOwned(segmenter)
            }
        };

        Ok(Self { inner, granularity })
    }

    /// Segment text into units
    ///
    /// # Arguments
    /// * `text` - Text to segment
    ///
    /// # Returns
    /// Array of Segment objects
    fn segment(&self, text: Value) -> Result<RArray, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");

        let text_str: String = TryConvert::try_convert(text)
            .map_err(|_| Error::new(ruby.exception_type_error(), "text must be a String"))?;

        // Get the Segment class
        let segment_class: RClass = ruby.eval("ICU4X::Segmenter::Segment")?;
        let result = ruby.ary_new();

        match &self.inner {
            SegmenterKind::GraphemeBorrowed(segmenter) => {
                self.segment_grapheme(segmenter, &text_str, &segment_class, &result)?;
            }
            SegmenterKind::GraphemeOwned(segmenter) => {
                let borrowed = segmenter.as_borrowed();
                self.segment_grapheme(&borrowed, &text_str, &segment_class, &result)?;
            }
            SegmenterKind::WordBorrowed(segmenter) => {
                self.segment_word(segmenter, &text_str, &segment_class, &result)?;
            }
            SegmenterKind::WordOwned(segmenter) => {
                let borrowed = segmenter.as_borrowed();
                self.segment_word(&borrowed, &text_str, &segment_class, &result)?;
            }
            SegmenterKind::SentenceOwned(segmenter) => {
                let borrowed = segmenter.as_borrowed();
                self.segment_sentence(&borrowed, &text_str, &segment_class, &result)?;
            }
            SegmenterKind::LineOwned(segmenter) => {
                let borrowed = segmenter.as_borrowed();
                self.segment_line(&borrowed, &text_str, &segment_class, &result)?;
            }
        }

        Ok(result)
    }

    fn segment_grapheme(
        &self,
        segmenter: &GraphemeClusterSegmenterBorrowed<'_>,
        text_str: &str,
        segment_class: &RClass,
        result: &RArray,
    ) -> Result<(), Error> {
        let mut prev_index = 0;
        for break_index in segmenter.segment_str(text_str) {
            if break_index > prev_index {
                let segment_str = &text_str[prev_index..break_index];
                let segment = segment_class.funcall::<_, _, Value>(
                    "new",
                    (segment_str, prev_index, Option::<bool>::None),
                )?;
                result.push(segment)?;
            }
            prev_index = break_index;
        }
        Ok(())
    }

    fn segment_word(
        &self,
        segmenter: &WordSegmenterBorrowed<'_>,
        text_str: &str,
        segment_class: &RClass,
        result: &RArray,
    ) -> Result<(), Error> {
        let mut prev_index = 0;
        let iter = segmenter.segment_str(text_str);
        for (break_index, word_type) in iter.iter_with_word_type() {
            if break_index > prev_index {
                let segment_str = &text_str[prev_index..break_index];
                let is_word_like = word_type.is_word_like();
                let segment = segment_class
                    .funcall::<_, _, Value>("new", (segment_str, prev_index, Some(is_word_like)))?;
                result.push(segment)?;
            }
            prev_index = break_index;
        }
        Ok(())
    }

    fn segment_sentence(
        &self,
        segmenter: &SentenceSegmenterBorrowed<'_>,
        text_str: &str,
        segment_class: &RClass,
        result: &RArray,
    ) -> Result<(), Error> {
        let mut prev_index = 0;
        for break_index in segmenter.segment_str(text_str) {
            if break_index > prev_index {
                let segment_str = &text_str[prev_index..break_index];
                let segment = segment_class.funcall::<_, _, Value>(
                    "new",
                    (segment_str, prev_index, Option::<bool>::None),
                )?;
                result.push(segment)?;
            }
            prev_index = break_index;
        }
        Ok(())
    }

    fn segment_line(
        &self,
        segmenter: &LineSegmenterBorrowed<'_>,
        text_str: &str,
        segment_class: &RClass,
        result: &RArray,
    ) -> Result<(), Error> {
        let mut prev_index = 0;
        for break_index in segmenter.segment_str(text_str) {
            if break_index > prev_index {
                let segment_str = &text_str[prev_index..break_index];
                let segment = segment_class.funcall::<_, _, Value>(
                    "new",
                    (segment_str, prev_index, Option::<bool>::None),
                )?;
                result.push(segment)?;
            }
            prev_index = break_index;
        }
        Ok(())
    }

    /// Get the resolved options
    ///
    /// # Returns
    /// A hash with :granularity
    fn resolved_options(&self) -> Result<RHash, Error> {
        let ruby = Ruby::get().expect("Ruby runtime should be available");
        let hash = ruby.hash_new();
        hash.aset(
            ruby.to_symbol("granularity"),
            ruby.to_symbol(self.granularity.to_symbol_name()),
        )?;
        Ok(hash)
    }
}

pub fn init(ruby: &Ruby, module: &RModule) -> Result<(), Error> {
    let class = module.define_class("Segmenter", ruby.class_object())?;
    class.define_singleton_method("new", function!(Segmenter::new, -1))?;
    class.define_method("segment", method!(Segmenter::segment, 1))?;
    class.define_method("resolved_options", method!(Segmenter::resolved_options, 0))?;
    Ok(())
}
