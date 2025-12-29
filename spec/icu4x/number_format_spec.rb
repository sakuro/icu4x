# frozen_string_literal: true

require "bigdecimal"
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

    it "creates a NumberFormat instance with style: :currency" do
      formatter = ICU4X::NumberFormat.new(locale, provider:, style: :currency, currency: "USD")

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
          .to raise_error(ArgumentError, /style must be :decimal, :percent, or :currency/)
      end

      it "raises ArgumentError when style is :currency but currency is missing" do
        expect { ICU4X::NumberFormat.new(locale, provider:, style: :currency) }
          .to raise_error(ArgumentError, /currency is required when style is :currency/)
      end

      it "raises ArgumentError when currency code is invalid" do
        expect { ICU4X::NumberFormat.new(locale, provider:, style: :currency, currency: "INVALID") }
          .to raise_error(ArgumentError, /currency must be a valid 3-letter ISO 4217 code/)
      end

      it "raises ArgumentError when minimum_integer_digits is negative" do
        expect { ICU4X::NumberFormat.new(locale, provider:, minimum_integer_digits: -1) }
          .to raise_error(ArgumentError, /minimum_integer_digits must be non-negative/)
      end

      it "raises ArgumentError when minimum_fraction_digits is negative" do
        expect { ICU4X::NumberFormat.new(locale, provider:, minimum_fraction_digits: -1) }
          .to raise_error(ArgumentError, /minimum_fraction_digits must be non-negative/)
      end

      it "raises ArgumentError when maximum_fraction_digits is negative" do
        expect { ICU4X::NumberFormat.new(locale, provider:, maximum_fraction_digits: -1) }
          .to raise_error(ArgumentError, /maximum_fraction_digits must be non-negative/)
      end

      it "raises ArgumentError when rounding_mode is invalid" do
        expect { ICU4X::NumberFormat.new(locale, provider:, maximum_fraction_digits: 2, rounding_mode: :invalid) }
          .to raise_error(ArgumentError, /rounding_mode must be/)
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

    context "with style: :currency and USD" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:, style: :currency, currency: "USD") }

      it "formats with dollar sign" do
        expect(formatter.format(1234.56)).to eq("$1,234.56")
      end

      it "formats integers" do
        expect(formatter.format(100)).to eq("$100")
      end

      it "formats negative amounts" do
        expect(formatter.format(-50)).to eq("$-50")
      end
    end

    context "with style: :currency and JPY" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("ja-JP"), provider:, style: :currency, currency: "JPY") }

      it "formats with yen sign and no decimal places" do
        expect(formatter.format(1234)).to eq("￥1,234")
      end
    end

    context "with style: :currency and EUR in de-DE locale" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("de-DE"), provider:, style: :currency, currency: "EUR") }

      it "formats with euro sign and German conventions" do
        expect(formatter.format(1234.56)).to eq("1.234,56\u00A0€")
      end
    end

    context "with BigDecimal" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:) }

      it "formats BigDecimal values" do
        expect(formatter.format(BigDecimal("1234.56"))).to eq("1,234.56")
      end

      it "formats large BigDecimal values with full precision" do
        expect(formatter.format(BigDecimal("12345678901234567890.123456789"))).to eq("12,345,678,901,234,567,890.123456789")
      end

      it "formats BigDecimal zero" do
        expect(formatter.format(BigDecimal(0))).to eq("0.0")
      end

      it "formats negative BigDecimal" do
        expect(formatter.format(BigDecimal("-1234.56"))).to eq("-1,234.56")
      end
    end

    context "with invalid number" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:) }

      it "raises TypeError for string" do
        expect { formatter.format("1234") }.to raise_error(TypeError, /number must be an Integer, Float, or BigDecimal/)
      end
    end

    context "with minimum_integer_digits" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:, minimum_integer_digits: 5) }

      it "pads integers with leading zeros" do
        expect(formatter.format(42)).to eq("00,042")
      end

      it "does not truncate larger integers" do
        expect(formatter.format(123_456)).to eq("123,456")
      end
    end

    context "with minimum_fraction_digits" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:, minimum_fraction_digits: 3) }

      it "pads decimals with trailing zeros" do
        expect(formatter.format(1.5)).to eq("1.500")
      end

      it "pads integers with trailing zeros" do
        expect(formatter.format(42)).to eq("42.000")
      end
    end

    context "with maximum_fraction_digits" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:, maximum_fraction_digits: 2) }

      it "rounds to specified decimal places" do
        expect(formatter.format(1.567)).to eq("1.57")
      end

      it "uses half_expand rounding by default" do
        expect(formatter.format(1.235)).to eq("1.24")
        expect(formatter.format(1.245)).to eq("1.25")
        expect(formatter.format(1.255)).to eq("1.26")
        expect(formatter.format(1.265)).to eq("1.27")
      end
    end

    context "with combined minimum and maximum fraction digits" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:, minimum_fraction_digits: 2, maximum_fraction_digits: 2) }

      it "formats integers with exactly 2 decimal places" do
        expect(formatter.format(100)).to eq("100.00")
      end

      it "rounds and pads to exactly 2 decimal places" do
        expect(formatter.format(1.5)).to eq("1.50")
        expect(formatter.format(1.567)).to eq("1.57")
      end
    end

    context "with rounding_mode: :half_expand (default)" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:, maximum_fraction_digits: 0) }

      it "rounds 0.5 away from zero" do
        expect(formatter.format(1.5)).to eq("2")
        expect(formatter.format(2.5)).to eq("3")
        expect(formatter.format(-1.5)).to eq("-2")
      end
    end

    context "with rounding_mode: :half_even" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:, maximum_fraction_digits: 0, rounding_mode: :half_even) }

      it "rounds 0.5 to even" do
        expect(formatter.format(1.5)).to eq("2")
        expect(formatter.format(2.5)).to eq("2")
        expect(formatter.format(3.5)).to eq("4")
      end
    end

    context "with rounding_mode: :ceil" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:, maximum_fraction_digits: 0, rounding_mode: :ceil) }

      it "rounds toward positive infinity" do
        expect(formatter.format(1.1)).to eq("2")
        expect(formatter.format(-1.1)).to eq("-1")
      end
    end

    context "with rounding_mode: :floor" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:, maximum_fraction_digits: 0, rounding_mode: :floor) }

      it "rounds toward negative infinity" do
        expect(formatter.format(1.9)).to eq("1")
        expect(formatter.format(-1.1)).to eq("-2")
      end
    end

    context "with rounding_mode: :trunc" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:formatter) { ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:, maximum_fraction_digits: 0, rounding_mode: :trunc) }

      it "rounds toward zero" do
        expect(formatter.format(1.9)).to eq("1")
        expect(formatter.format(-1.9)).to eq("-1")
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

    it "returns style: :currency and currency when specified" do
      formatter = ICU4X::NumberFormat.new(ICU4X::Locale.parse("en-US"), provider:, style: :currency, currency: "USD")

      expect(formatter.resolved_options).to eq({
        locale: "en-US",
        style: :currency,
        use_grouping: true,
        currency: "USD"
      })
    end

    it "returns digit options and rounding_mode when specified" do
      formatter = ICU4X::NumberFormat.new(
        ICU4X::Locale.parse("en-US"),
        provider:,
        minimum_integer_digits: 3,
        minimum_fraction_digits: 2,
        maximum_fraction_digits: 4,
        rounding_mode: :half_even
      )

      expect(formatter.resolved_options).to eq({
        locale: "en-US",
        style: :decimal,
        use_grouping: true,
        minimum_integer_digits: 3,
        minimum_fraction_digits: 2,
        maximum_fraction_digits: 4,
        rounding_mode: :half_even
      })
    end
  end
end
