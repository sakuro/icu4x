# Segmenter

Text segmentation for grapheme clusters, words, sentences, and line breaks. Equivalent to JavaScript's Intl.Segmenter.

---

## Class Structure

```
ICU4X
└─ Segmenter
   └─ Segment
```

---

## ICU4X::Segmenter

A class for segmenting text into meaningful units.

### Interface

```ruby
module ICU4X
  class Segmenter
    # Constructor
    # @param granularity [Symbol] :grapheme, :word, :sentence, or :line
    # @param provider [DataProvider] Data provider (optional for :grapheme and :word)
    # @raise [ArgumentError] If granularity is invalid or provider is missing when required
    # @raise [TypeError] If provider is not a DataProvider
    # @raise [Error] If data loading fails
    def initialize(granularity:, provider: nil) = ...

    # Segment text into units
    # @param text [String] Text to segment
    # @return [Array<Segment>]
    # @raise [TypeError] If text is not a String
    def segment(text) = ...

    # Get resolved options
    # @return [Hash]
    def resolved_options = ...
  end
end
```

---

## ICU4X::Segmenter::Segment

A Data class representing a segment of text.

### Interface

```ruby
module ICU4X
  class Segmenter
    class Segment
      # @return [String] The segment string
      attr_reader :segment

      # @return [Integer] Byte offset in original text
      attr_reader :index

      # Whether this segment is word-like
      # @return [Boolean] true if word-like (letters, numbers, CJK ideographs)
      # @return [nil] for non-word granularity
      def word_like? = ...
    end
  end
end
```

---

## granularity Option

| Value | Description | Provider Required |
|-------|-------------|-------------------|
| `:grapheme` | Grapheme clusters (user-perceived characters) | No |
| `:word` | Words and word-like units | No |
| `:sentence` | Sentences | Yes |
| `:line` | Line break opportunities | Yes |

---

## Usage Examples

### Grapheme Segmentation

```ruby
segmenter = ICU4X::Segmenter.new(granularity: :grapheme)

segments = segmenter.segment("こんにちは")
segments.map(&:segment)
# => ["こ", "ん", "に", "ち", "は"]

# Handles complex grapheme clusters
segments = segmenter.segment("👨‍👩‍👧‍👦")
segments.map(&:segment)
# => ["👨‍👩‍👧‍👦"]  # Family emoji is a single grapheme
```

### Word Segmentation

```ruby
segmenter = ICU4X::Segmenter.new(granularity: :word)

segments = segmenter.segment("Hello, world!")
segments.map(&:segment)
# => ["Hello", ",", " ", "world", "!"]

# Filter to word-like segments only
words = segments.select(&:word_like?).map(&:segment)
# => ["Hello", "world"]
```

### Japanese Word Segmentation

```ruby
provider = ICU4X::DataProvider.from_blob(Pathname.new("data/i18n.blob"))
segmenter = ICU4X::Segmenter.new(granularity: :word, provider: provider)

segments = segmenter.segment("今日は天気がいいです")
words = segments.select(&:word_like?).map(&:segment)
# => ["今日", "は", "天気", "が", "いい", "です"]
```

### Sentence Segmentation

```ruby
provider = ICU4X::DataProvider.from_blob(Pathname.new("data/i18n.blob"))
segmenter = ICU4X::Segmenter.new(granularity: :sentence, provider: provider)

text = "Hello! How are you? I'm fine."
segments = segmenter.segment(text)
segments.map(&:segment)
# => ["Hello! ", "How are you? ", "I'm fine."]
```

### Line Break Segmentation

```ruby
provider = ICU4X::DataProvider.from_blob(Pathname.new("data/i18n.blob"))
segmenter = ICU4X::Segmenter.new(granularity: :line, provider: provider)

text = "This is a long text that needs line breaking."
segments = segmenter.segment(text)
# Each segment represents a potential line break point
```

### Byte Offset Access

```ruby
segmenter = ICU4X::Segmenter.new(granularity: :word)

segments = segmenter.segment("こんにちは, world!")
segments.each do |seg|
  puts "#{seg.segment.inspect} at byte #{seg.index}"
end
# "こんにちは" at byte 0
# "," at byte 15
# " " at byte 16
# "world" at byte 17
# "!" at byte 22
```

---

## Notes

- Grapheme segmentation handles Unicode correctly (emoji, combining characters, etc.)
- Word segmentation includes `word_like?` to distinguish words from punctuation/whitespace
- For `:grapheme` and `:word`, a provider is optional (uses compiled data)
- For `:sentence` and `:line`, a provider is required
- The `index` attribute returns byte offset, not character offset
- Japanese/Chinese/Korean text requires dictionary data for accurate word segmentation
