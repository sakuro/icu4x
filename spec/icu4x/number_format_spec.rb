# frozen_string_literal: true

require "pathname"

RSpec.describe ICU4X::NumberFormat do
  let(:fixtures_path) { Pathname.new(__dir__).parent / "fixtures" }
  let(:valid_blob_path) { fixtures_path / "test-data.postcard" }

  describe ".new" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
    let(:locale) { ICU4X::Locale.parse("en-US") }

    it "creates a NumberFormat instance with default options" do
      formatter = ICU4X::NumberFormat.new(locale, provider:)

      expect(formatter).to be_a(ICU4X::NumberFormat)
    end

    it "creates a NumberFormat instance with use_grouping: false" do
      formatter = ICU4X::NumberFormat.new(locale, provider:, use_grouping: false)

      expect(formatter).to be_a(ICU4X::NumberFormat)
    end

    it "creates a NumberFormat instance with style: :percent" do
      formatter = ICU4X::NumberFormat.new(locale, provider:, style: :percent)

      expect(formatter).to be_a(ICU4X::NumberFormat)
    end

    context "with invalid arguments" do
      it "raises ArgumentError when missing provider keyword" do
        expect { ICU4X::NumberFormat.new(locale) }
          .to raise_error(ArgumentError, /missing keyword: :provider/)
      end

      it "raises TypeError when provider is invalid type" do
        expect { ICU4X::NumberFormat.new(locale, provider: "not a provider") }
          .to raise_error(TypeError, /provider must be a DataProvider/)
      end

      it "raises ArgumentError when style is invalid" do
        expect { ICU4X::NumberFormat.new(locale, provider:, style: :invalid) }
          .to raise_error(ArgumentError, /style must be :decimal or :percent/)
      end
    end
  end

  describe "#format" do
    context "with en-US locale" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:) }

      it "formats integers with grouping" do
        expect(formatter.format(1_234_567)).to eq("1,234,567")
      end

      it "formats floats" do
        expect(formatter.format(1234.56)).to eq("1,234.56")
      end

      it "formats zero" do
        expect(formatter.format(0)).to eq("0")
      end

      it "formats negative numbers" do
        expect(formatter.format(-1234)).to eq("-1,234")
      end
    end

    context "with ja-JP locale" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("ja-JP"), provider:) }

      it "formats integers with grouping" do
        expect(formatter.format(1_234_567)).to eq("1,234,567")
      end
    end

    context "with de-DE locale" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("de-DE"), provider:) }

      it "formats integers with German grouping (period)" do
        expect(formatter.format(1_234_567)).to eq("1.234.567")
      end

      it "formats floats with German decimal separator (comma)" do
        expect(formatter.format(1234.56)).to eq("1.234,56")
      end
    end

    context "with use_grouping: false" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:, use_grouping: false) }

      it "formats integers without grouping" do
        expect(formatter.format(1_234_567)).to eq("1234567")
      end
    end

    context "with style: :percent" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:, style: :percent) }

      it "formats integers with percent sign" do
        expect(formatter.format(25)).to eq("25%")
      end

      it "formats floats with percent sign" do
        expect(formatter.format(12.5)).to eq("12.5%")
      end

      it "formats negative percentages" do
        expect(formatter.format(-5)).to eq("-5%")
      end
    end

    context "with style: :percent and de-DE locale" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("de-DE"), provider:, style: :percent) }

      it "formats with German conventions" do
        expect(formatter.format(1234.5)).to eq("1.234,5\u00A0%")
      end
    end

    context "with invalid number" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:) }

      it "raises TypeError for string" do
        expect { formatter.format("1234") }.to raise_error(TypeError, /number must be an Integer or Float/)
      end
    end
  end

  describe "#resolved_options" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

    it "returns locale, style, and use_grouping" do
      formatter = ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:)

      expect(formatter.resolved_options).to eq({
        locale: "en-US",
        style: :decimal,
        use_grouping: true
      })
    end

    it "returns use_grouping: false when specified" do
      formatter = ICU4X::NumberFormat.new(ICU4X::Locale.parse("ja-JP"), provider:, use_grouping: false)

      expect(formatter.resolved_options).to eq({
        locale: "ja-JP",
        style: :decimal,
        use_grouping: false
      })
    end

    it "returns style: :percent when specified" do
      formatter = ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:, style: :percent)

      expect(formatter.resolved_options).to eq({
        locale: "en-US",
        style: :percent,
        use_grouping: true
      })
    end
  end
end
