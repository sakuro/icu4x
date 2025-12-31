# frozen_string_literal: true

require "pathname"

RSpec.describe ICU4X::Segmenter do
  let(:fixtures_path) { Pathname.new(__dir__).parent / "fixtures" }
  let(:valid_blob_path) { fixtures_path / "test-data.postcard" }

  describe ".new" do
    context "with granularity: :grapheme" do
      it "creates without provider" do
        segmenter = ICU4X::Segmenter.new(granularity: :grapheme)

        expect(segmenter).to be_a(ICU4X::Segmenter)
      end
    end

    context "with granularity: :word" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

      it "creates with provider" do
        segmenter = ICU4X::Segmenter.new(granularity: :word, provider:)

        expect(segmenter).to be_a(ICU4X::Segmenter)
      end

      it "creates without provider (uses built-in)" do
        segmenter = ICU4X::Segmenter.new(granularity: :word)

        expect(segmenter).to be_a(ICU4X::Segmenter)
      end
    end

    context "with granularity: :sentence" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

      it "creates with provider" do
        segmenter = ICU4X::Segmenter.new(granularity: :sentence, provider:)

        expect(segmenter).to be_a(ICU4X::Segmenter)
      end

      it "raises ArgumentError without provider" do
        expect { ICU4X::Segmenter.new(granularity: :sentence) }
          .to raise_error(ArgumentError, /provider is required for sentence segmentation/)
      end
    end

    context "with granularity: :line" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

      it "creates with provider" do
        segmenter = ICU4X::Segmenter.new(granularity: :line, provider:)

        expect(segmenter).to be_a(ICU4X::Segmenter)
      end

      it "raises ArgumentError without provider" do
        expect { ICU4X::Segmenter.new(granularity: :line) }
          .to raise_error(ArgumentError, /provider is required for line segmentation/)
      end
    end

    context "with invalid arguments" do
      it "raises ArgumentError when missing granularity keyword" do
        expect { ICU4X::Segmenter.new }
          .to raise_error(ArgumentError, /missing keyword: :granularity/)
      end

      it "raises ArgumentError for invalid granularity" do
        expect { ICU4X::Segmenter.new(granularity: :invalid) }
          .to raise_error(ArgumentError, /granularity must be :grapheme, :word, :sentence, or :line/)
      end

      it "raises TypeError when provider is invalid type" do
        expect { ICU4X::Segmenter.new(granularity: :sentence, provider: "not a provider") }
          .to raise_error(TypeError, /provider must be a DataProvider/)
      end
    end
  end

  describe "#segment" do
    context "with granularity: :grapheme" do
      let(:segmenter) { ICU4X::Segmenter.new(granularity: :grapheme) }

      it "segments ASCII text" do
        segments = segmenter.segment("abc")

        expect(segments.map(&:segment)).to eq(%w[a b c])
      end

      it "segments combining characters" do
        # café - the é is a single grapheme even if composed
        segments = segmenter.segment("café")

        expect(segments.map(&:segment)).to eq(%w[c a f é])
      end

      it "segments emoji with ZWJ" do
        # Family emoji (👨‍👩‍👧) is a single grapheme
        segments = segmenter.segment("👨‍👩‍👧")

        expect(segments.size).to eq(1)
        expect(segments.first.segment).to eq("👨‍👩‍👧")
      end

      it "segments Korean hangul" do
        segments = segmenter.segment("한글")

        expect(segments.map(&:segment)).to eq(%w[한 글])
      end

      it "returns correct byte indices" do
        segments = segmenter.segment("abc")

        expect(segments.map(&:index)).to eq([0, 1, 2])
      end

      it "returns nil for word_like?" do
        segments = segmenter.segment("abc")

        expect(segments.map(&:word_like?)).to all(be_nil)
      end
    end

    context "with granularity: :word" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:segmenter) { ICU4X::Segmenter.new(granularity: :word, provider:) }

      it "segments English words" do
        segments = segmenter.segment("Hello, world!")

        expect(segments.map(&:segment)).to eq(["Hello", ",", " ", "world", "!"])
      end

      it "identifies word-like segments" do
        segments = segmenter.segment("Hello, world!")
        word_like = segments.filter_map {|s| s.segment if s.word_like? }

        expect(word_like).to eq(%w[Hello world])
      end

      it "identifies non-word-like segments" do
        segments = segmenter.segment("Hello, world!")
        non_word_like = segments.filter_map {|s| s.segment unless s.word_like? }

        expect(non_word_like).to eq([",", " ", "!"])
      end

      it "segments Japanese text" do
        segments = segmenter.segment("今日は良い天気です")
        words = segments.filter_map {|s| s.segment if s.word_like? }

        expect(words).to eq(%w[今日 は 良い 天気 です])
      end

      it "returns correct byte indices for multibyte text" do
        # "こんにちは" (5 chars × 3 bytes = 15 bytes) + ", " (2 bytes) = 17 bytes before "world"
        segments = segmenter.segment("こんにちは, world!")
        # "world" should start at byte offset 17
        world_segment = segments.find {|s| s.segment == "world" }

        expect(world_segment.index).to eq(17)
      end
    end

    context "with granularity: :sentence" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:segmenter) { ICU4X::Segmenter.new(granularity: :sentence, provider:) }

      it "segments by sentence boundaries" do
        segments = segmenter.segment("Hello there. How are you? I'm fine!")

        expect(segments.map(&:segment)).to eq(["Hello there. ", "How are you? ", "I'm fine!"])
      end

      it "returns nil for word_like?" do
        segments = segmenter.segment("Hello. World.")

        expect(segments.map(&:word_like?)).to all(be_nil)
      end
    end

    context "with granularity: :line" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:segmenter) { ICU4X::Segmenter.new(granularity: :line, provider:) }

      it "identifies line break opportunities" do
        segments = segmenter.segment("Hello world")

        expect(segments.map(&:segment)).to eq(["Hello ", "world"])
      end

      it "returns nil for word_like?" do
        segments = segmenter.segment("Hello world")

        expect(segments.map(&:word_like?)).to all(be_nil)
      end
    end

    it "raises TypeError for non-string input" do
      segmenter = ICU4X::Segmenter.new(granularity: :grapheme)

      expect { segmenter.segment(123) }
        .to raise_error(TypeError, /text must be a String/)
    end

    it "returns empty array for empty string" do
      segmenter = ICU4X::Segmenter.new(granularity: :grapheme)
      segments = segmenter.segment("")

      expect(segments).to eq([])
    end
  end

  describe "#resolved_options" do
    it "returns hash with granularity for grapheme" do
      segmenter = ICU4X::Segmenter.new(granularity: :grapheme)

      expect(segmenter.resolved_options).to eq({granularity: :grapheme})
    end

    it "returns hash with granularity for word" do
      segmenter = ICU4X::Segmenter.new(granularity: :word)

      expect(segmenter.resolved_options).to eq({granularity: :word})
    end

    it "returns hash with granularity for sentence" do
      provider = ICU4X::DataProvider.from_blob(valid_blob_path)
      segmenter = ICU4X::Segmenter.new(granularity: :sentence, provider:)

      expect(segmenter.resolved_options).to eq({granularity: :sentence})
    end

    it "returns hash with granularity for line" do
      provider = ICU4X::DataProvider.from_blob(valid_blob_path)
      segmenter = ICU4X::Segmenter.new(granularity: :line, provider:)

      expect(segmenter.resolved_options).to eq({granularity: :line})
    end
  end

  describe ICU4X::Segmenter::Segment do
    it "responds to #segment" do
      segment = ICU4X::Segmenter::Segment.new(segment: "test", index: 0, word_like: nil)

      expect(segment).to respond_to(:segment)
      expect(segment.segment).to eq("test")
    end

    it "responds to #index" do
      segment = ICU4X::Segmenter::Segment.new(segment: "test", index: 5, word_like: nil)

      expect(segment).to respond_to(:index)
      expect(segment.index).to eq(5)
    end

    it "responds to #word_like?" do
      segment = ICU4X::Segmenter::Segment.new(segment: "test", index: 0, word_like: true)

      expect(segment).to respond_to(:word_like?)
      expect(segment.word_like?).to be(true)
    end

    it "allows nil for word_like?" do
      segment = ICU4X::Segmenter::Segment.new(segment: "test", index: 0, word_like: nil)

      expect(segment.word_like?).to be_nil
    end
  end
end
