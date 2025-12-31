# frozen_string_literal: true

require "pathname"

RSpec.describe ICU4X::Collator do
  let(:fixtures_path) { Pathname.new(__dir__).parent / "fixtures" }
  let(:valid_blob_path) { fixtures_path / "test-data.postcard" }

  describe ".new" do
    context "with DataProvider" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:locale) { ICU4X::Locale.parse("en") }

      it "creates with default options" do
        collator = ICU4X::Collator.new(locale, provider:)

        expect(collator).to be_a(ICU4X::Collator)
      end

      it "creates with sensitivity: :base" do
        collator = ICU4X::Collator.new(locale, provider:, sensitivity: :base)

        expect(collator).to be_a(ICU4X::Collator)
      end

      it "creates with sensitivity: :accent" do
        collator = ICU4X::Collator.new(locale, provider:, sensitivity: :accent)

        expect(collator).to be_a(ICU4X::Collator)
      end

      it "creates with sensitivity: :case" do
        collator = ICU4X::Collator.new(locale, provider:, sensitivity: :case)

        expect(collator).to be_a(ICU4X::Collator)
      end

      it "creates with numeric: true" do
        collator = ICU4X::Collator.new(locale, provider:, numeric: true)

        expect(collator).to be_a(ICU4X::Collator)
      end

      it "creates with case_first: :upper" do
        collator = ICU4X::Collator.new(locale, provider:, case_first: :upper)

        expect(collator).to be_a(ICU4X::Collator)
      end

      it "creates with case_first: :lower" do
        collator = ICU4X::Collator.new(locale, provider:, case_first: :lower)

        expect(collator).to be_a(ICU4X::Collator)
      end
    end

    context "with optional provider" do
      let(:locale) { ICU4X::Locale.parse("en") }

      around do |example|
        original_env = ENV.fetch("ICU4X_DATA_PATH", nil)
        ENV["ICU4X_DATA_PATH"] = valid_blob_path.to_s
        example.run
      ensure
        ENV["ICU4X_DATA_PATH"] = original_env
      end

      it "uses default provider when provider is not specified" do
        collator = ICU4X::Collator.new(locale)
        expect(collator.compare("a", "b")).to eq(-1)
      end
    end

    context "with invalid arguments" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:locale) { ICU4X::Locale.parse("en") }

      around do |example|
        original_env = ENV.fetch("ICU4X_DATA_PATH", nil)
        ENV.delete("ICU4X_DATA_PATH")
        example.run
      ensure
        ENV["ICU4X_DATA_PATH"] = original_env
      end

      it "raises ArgumentError when no provider is available" do
        expect { ICU4X::Collator.new(locale) }
          .to raise_error(ArgumentError, /No provider specified and no default configured/)
      end

      it "raises ArgumentError for invalid sensitivity" do
        expect { ICU4X::Collator.new(locale, provider:, sensitivity: :invalid) }
          .to raise_error(ArgumentError, /sensitivity must be :base, :accent, :case, or :variant/)
      end

      it "raises ArgumentError for invalid case_first" do
        expect { ICU4X::Collator.new(locale, provider:, case_first: :invalid) }
          .to raise_error(ArgumentError, /case_first must be :upper, :lower, or nil/)
      end

      it "raises TypeError when provider is invalid type" do
        expect { ICU4X::Collator.new(locale, provider: "not a provider") }
          .to raise_error(TypeError, /provider must be a DataProvider/)
      end
    end
  end

  describe "#compare" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
    let(:locale) { ICU4X::Locale.parse("en") }
    let(:collator) { ICU4X::Collator.new(locale, provider:) }

    it "returns -1 when first < second" do
      expect(collator.compare("apple", "banana")).to eq(-1)
    end

    it "returns 0 when equal" do
      expect(collator.compare("apple", "apple")).to eq(0)
    end

    it "returns 1 when first > second" do
      expect(collator.compare("banana", "apple")).to eq(1)
    end

    context "with sensitivity: :base" do
      let(:collator) { ICU4X::Collator.new(locale, provider:, sensitivity: :base) }

      it "ignores case differences" do
        expect(collator.compare("a", "A")).to eq(0)
      end

      it "ignores accent differences" do
        expect(collator.compare("a", "á")).to eq(0)
      end
    end

    context "with sensitivity: :accent" do
      let(:collator) { ICU4X::Collator.new(locale, provider:, sensitivity: :accent) }

      it "ignores case differences" do
        expect(collator.compare("a", "A")).to eq(0)
      end

      it "detects accent differences" do
        expect(collator.compare("a", "á")).not_to eq(0)
      end
    end

    context "with sensitivity: :case" do
      let(:collator) { ICU4X::Collator.new(locale, provider:, sensitivity: :case) }

      it "detects case differences" do
        expect(collator.compare("a", "A")).not_to eq(0)
      end

      it "ignores accent differences" do
        expect(collator.compare("a", "á")).to eq(0)
      end
    end

    context "with numeric: true" do
      let(:collator) { ICU4X::Collator.new(locale, provider:, numeric: true) }

      it "sorts numbers numerically within strings" do
        expect(collator.compare("file2", "file10")).to eq(-1)
      end
    end

    context "without numeric option (default)" do
      it "sorts numbers lexicographically" do
        expect(collator.compare("file2", "file10")).to eq(1)
      end
    end

    context "with German locale" do
      let(:locale_de) { ICU4X::Locale.parse("de") }
      let(:collator) { ICU4X::Collator.new(locale_de, provider:) }

      it "handles German umlauts" do
        # In German, ä is treated as a variant of a
        result = collator.compare("ä", "b")

        expect(result).to eq(-1)
      end
    end

    context "with Japanese locale" do
      let(:locale_ja) { ICU4X::Locale.parse("ja") }
      let(:collator) { ICU4X::Collator.new(locale_ja, provider:) }

      it "sorts hiragana correctly" do
        expect(collator.compare("あ", "い")).to eq(-1)
        expect(collator.compare("い", "う")).to eq(-1)
      end
    end

    context "with invalid arguments" do
      it "raises TypeError for non-string first argument" do
        expect { collator.compare(123, "test") }
          .to raise_error(TypeError, /first argument must be a String/)
      end

      it "raises TypeError for non-string second argument" do
        expect { collator.compare("test", 123) }
          .to raise_error(TypeError, /second argument must be a String/)
      end
    end
  end

  describe "#resolved_options" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

    it "returns hash with default options" do
      collator = ICU4X::Collator.new(ICU4X::Locale.parse("en"), provider:)

      expect(collator.resolved_options).to eq({
        locale: "en",
        sensitivity: :variant,
        numeric: false
      })
    end

    it "returns hash with custom options" do
      collator = ICU4X::Collator.new(
        ICU4X::Locale.parse("ja"),
        provider:,
        sensitivity: :base,
        numeric: true,
        case_first: :upper
      )

      expect(collator.resolved_options).to eq({
        locale: "ja",
        sensitivity: :base,
        numeric: true,
        case_first: :upper
      })
    end
  end
end
