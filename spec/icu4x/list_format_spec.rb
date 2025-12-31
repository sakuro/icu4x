# frozen_string_literal: true

require "pathname"

RSpec.describe ICU4X::ListFormat do
  let(:fixtures_path) { Pathname.new(__dir__).parent / "fixtures" }
  let(:valid_blob_path) { fixtures_path / "test-data.postcard" }

  describe ".new" do
    context "with DataProvider" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:locale) { ICU4X::Locale.parse("en") }

      it "creates with default options" do
        lf = ICU4X::ListFormat.new(locale, provider:)

        expect(lf).to be_a(ICU4X::ListFormat)
      end

      it "creates with type: :conjunction" do
        lf = ICU4X::ListFormat.new(locale, provider:, type: :conjunction)

        expect(lf).to be_a(ICU4X::ListFormat)
      end

      it "creates with type: :disjunction" do
        lf = ICU4X::ListFormat.new(locale, provider:, type: :disjunction)

        expect(lf).to be_a(ICU4X::ListFormat)
      end

      it "creates with type: :unit" do
        lf = ICU4X::ListFormat.new(locale, provider:, type: :unit)

        expect(lf).to be_a(ICU4X::ListFormat)
      end

      it "creates with style: :short" do
        lf = ICU4X::ListFormat.new(locale, provider:, style: :short)

        expect(lf).to be_a(ICU4X::ListFormat)
      end

      it "creates with style: :narrow" do
        lf = ICU4X::ListFormat.new(locale, provider:, style: :narrow)

        expect(lf).to be_a(ICU4X::ListFormat)
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
        lf = ICU4X::ListFormat.new(locale)
        expect(lf.format(%w[a b c])).to eq("a, b, and c")
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
        expect { ICU4X::ListFormat.new(locale) }
          .to raise_error(ArgumentError, /No provider specified and no default configured/)
      end

      it "raises ArgumentError for invalid type" do
        expect { ICU4X::ListFormat.new(locale, provider:, type: :invalid) }
          .to raise_error(ArgumentError, /type must be :conjunction, :disjunction, or :unit/)
      end

      it "raises ArgumentError for invalid style" do
        expect { ICU4X::ListFormat.new(locale, provider:, style: :invalid) }
          .to raise_error(ArgumentError, /style must be :long, :short, or :narrow/)
      end

      it "raises TypeError when provider is invalid type" do
        expect { ICU4X::ListFormat.new(locale, provider: "not a provider") }
          .to raise_error(TypeError, /provider must be a DataProvider/)
      end
    end
  end

  describe "#format" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

    context "with type: :conjunction (default)" do
      let(:lf) { ICU4X::ListFormat.new(ICU4X::Locale.parse("en"), provider:) }

      it "formats empty array" do
        expect(lf.format([])).to eq("")
      end

      it "formats single item" do
        expect(lf.format(["A"])).to eq("A")
      end

      it "formats two items" do
        expect(lf.format(%w[A B])).to eq("A and B")
      end

      it "formats three items" do
        expect(lf.format(%w[A B C])).to eq("A, B, and C")
      end
    end

    context "with type: :disjunction" do
      let(:lf) { ICU4X::ListFormat.new(ICU4X::Locale.parse("en"), provider:, type: :disjunction) }

      it "formats with or" do
        expect(lf.format(%w[A B C])).to eq("A, B, or C")
      end

      it "formats two items with or" do
        expect(lf.format(%w[A B])).to eq("A or B")
      end
    end

    context "with type: :unit" do
      let(:lf) { ICU4X::ListFormat.new(ICU4X::Locale.parse("en"), provider:, type: :unit) }

      it "formats without conjunction" do
        expect(lf.format(["5 pounds", "3 ounces"])).to eq("5 pounds, 3 ounces")
      end
    end

    context "with Japanese locale" do
      let(:lf) { ICU4X::ListFormat.new(ICU4X::Locale.parse("ja"), provider:) }

      it "formats in Japanese style" do
        expect(lf.format(%w[A B C])).to eq("A、B、C")
      end
    end

    context "with German locale" do
      let(:lf) { ICU4X::ListFormat.new(ICU4X::Locale.parse("de"), provider:) }

      it "formats with und" do
        expect(lf.format(%w[A B C])).to eq("A, B und C")
      end
    end

    context "with style variations" do
      let(:locale) { ICU4X::Locale.parse("en") }

      it "formats with short style" do
        lf = ICU4X::ListFormat.new(locale, provider:, style: :short)

        expect(lf.format(%w[A B C])).to eq("A, B, & C")
      end

      it "formats with narrow style" do
        lf = ICU4X::ListFormat.new(locale, provider:, style: :narrow)

        expect(lf.format(%w[A B C])).to eq("A, B, C")
      end
    end

    context "with invalid input" do
      let(:lf) { ICU4X::ListFormat.new(ICU4X::Locale.parse("en"), provider:) }

      it "raises TypeError for non-array input" do
        expect { lf.format("not an array") }.to raise_error(TypeError, /list must be an Array/)
      end
    end
  end

  describe "#resolved_options" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

    it "returns hash with locale, type, style for defaults" do
      lf = ICU4X::ListFormat.new(ICU4X::Locale.parse("en"), provider:)

      expect(lf.resolved_options).to eq({locale: "en", type: :conjunction, style: :long})
    end

    it "returns hash with specified type and style" do
      lf = ICU4X::ListFormat.new(
        ICU4X::Locale.parse("ja"),
        provider:,
        type: :disjunction,
        style: :short
      )

      expect(lf.resolved_options).to eq({locale: "ja", type: :disjunction, style: :short})
    end
  end
end
