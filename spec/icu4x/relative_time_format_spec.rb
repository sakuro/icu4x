# frozen_string_literal: true

require "pathname"

RSpec.describe ICU4X::RelativeTimeFormat do
  let(:fixtures_path) { Pathname.new(__dir__).parent / "fixtures" }
  let(:valid_blob_path) { fixtures_path / "test-data.postcard" }

  describe ".new" do
    context "with DataProvider" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:locale) { ICU4X::Locale.parse("en") }

      it "creates with default options" do
        rtf = ICU4X::RelativeTimeFormat.new(locale, provider:)

        expect(rtf).to be_a(ICU4X::RelativeTimeFormat)
      end

      it "creates with style: :long" do
        rtf = ICU4X::RelativeTimeFormat.new(locale, provider:, style: :long)

        expect(rtf).to be_a(ICU4X::RelativeTimeFormat)
      end

      it "creates with style: :short" do
        rtf = ICU4X::RelativeTimeFormat.new(locale, provider:, style: :short)

        expect(rtf).to be_a(ICU4X::RelativeTimeFormat)
      end

      it "creates with style: :narrow" do
        rtf = ICU4X::RelativeTimeFormat.new(locale, provider:, style: :narrow)

        expect(rtf).to be_a(ICU4X::RelativeTimeFormat)
      end

      it "creates with numeric: :always" do
        rtf = ICU4X::RelativeTimeFormat.new(locale, provider:, numeric: :always)

        expect(rtf).to be_a(ICU4X::RelativeTimeFormat)
      end

      it "creates with numeric: :auto" do
        rtf = ICU4X::RelativeTimeFormat.new(locale, provider:, numeric: :auto)

        expect(rtf).to be_a(ICU4X::RelativeTimeFormat)
      end
    end

    context "with invalid arguments" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:locale) { ICU4X::Locale.parse("en") }

      it "raises ArgumentError when missing provider keyword" do
        expect { ICU4X::RelativeTimeFormat.new(locale) }
          .to raise_error(ArgumentError, /missing keyword: :provider/)
      end

      it "raises ArgumentError for invalid style" do
        expect { ICU4X::RelativeTimeFormat.new(locale, provider:, style: :invalid) }
          .to raise_error(ArgumentError, /style must be :long, :short, or :narrow/)
      end

      it "raises ArgumentError for invalid numeric" do
        expect { ICU4X::RelativeTimeFormat.new(locale, provider:, numeric: :invalid) }
          .to raise_error(ArgumentError, /numeric must be :always or :auto/)
      end

      it "raises TypeError when provider is invalid type" do
        expect { ICU4X::RelativeTimeFormat.new(locale, provider: "not a provider") }
          .to raise_error(TypeError, /provider must be a DataProvider/)
      end
    end
  end

  describe "#format" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

    context "with default options (style: :long, numeric: :always)" do
      let(:rtf) { ICU4X::RelativeTimeFormat.new(ICU4X::Locale.parse("en"), provider:) }

      it "formats past time with days" do
        result = rtf.format(-3, :day)

        expect(result).to eq("3 days ago")
      end

      it "formats future time with days" do
        result = rtf.format(2, :day)

        expect(result).to eq("in 2 days")
      end

      it "formats past time with hours" do
        result = rtf.format(-1, :hour)

        expect(result).to eq("1 hour ago")
      end

      it "formats future time with minutes" do
        result = rtf.format(5, :minute)

        expect(result).to eq("in 5 minutes")
      end

      it "formats past time with weeks" do
        result = rtf.format(-2, :week)

        expect(result).to eq("2 weeks ago")
      end

      it "formats future time with months" do
        result = rtf.format(1, :month)

        expect(result).to eq("in 1 month")
      end

      it "formats zero days" do
        result = rtf.format(0, :day)

        expect(result).to eq("in 0 days")
      end
    end

    context "with numeric: :auto" do
      let(:rtf) { ICU4X::RelativeTimeFormat.new(ICU4X::Locale.parse("en"), provider:, numeric: :auto) }

      it "uses 'yesterday' for -1 day" do
        result = rtf.format(-1, :day)

        expect(result).to eq("yesterday")
      end

      it "uses 'today' for 0 days" do
        result = rtf.format(0, :day)

        expect(result).to eq("today")
      end

      it "uses 'tomorrow' for 1 day" do
        result = rtf.format(1, :day)

        expect(result).to eq("tomorrow")
      end

      it "falls back to numeric for -2 days" do
        result = rtf.format(-2, :day)

        expect(result).to eq("2 days ago")
      end
    end

    context "with different units" do
      let(:rtf) { ICU4X::RelativeTimeFormat.new(ICU4X::Locale.parse("en"), provider:) }

      it "formats seconds" do
        result = rtf.format(-30, :second)

        expect(result).to eq("30 seconds ago")
      end

      it "formats minutes" do
        result = rtf.format(15, :minute)

        expect(result).to eq("in 15 minutes")
      end

      it "formats hours" do
        result = rtf.format(-2, :hour)

        expect(result).to eq("2 hours ago")
      end

      it "formats days" do
        result = rtf.format(3, :day)

        expect(result).to eq("in 3 days")
      end

      it "formats weeks" do
        result = rtf.format(-1, :week)

        expect(result).to eq("1 week ago")
      end

      it "formats months" do
        result = rtf.format(6, :month)

        expect(result).to eq("in 6 months")
      end

      it "formats quarters" do
        result = rtf.format(-2, :quarter)

        expect(result).to eq("2 quarters ago")
      end

      it "formats years" do
        result = rtf.format(1, :year)

        expect(result).to eq("in 1 year")
      end
    end

    context "with style: :short" do
      let(:rtf) { ICU4X::RelativeTimeFormat.new(ICU4X::Locale.parse("en"), provider:, style: :short) }

      it "uses abbreviated format" do
        result = rtf.format(-3, :hour)

        expect(result).to include("3")
        expect(result).to include("ago")
      end
    end

    context "with style: :narrow" do
      let(:rtf) { ICU4X::RelativeTimeFormat.new(ICU4X::Locale.parse("en"), provider:, style: :narrow) }

      it "uses minimal format" do
        result = rtf.format(-3, :hour)

        expect(result).to include("3")
      end
    end

    context "with Japanese locale" do
      let(:rtf) { ICU4X::RelativeTimeFormat.new(ICU4X::Locale.parse("ja"), provider:) }

      it "formats past time in Japanese" do
        result = rtf.format(-3, :day)

        expect(result).to include("3")
      end

      it "formats future time in Japanese" do
        result = rtf.format(1, :week)

        expect(result).to include("1")
      end
    end

    context "with invalid unit" do
      let(:rtf) { ICU4X::RelativeTimeFormat.new(ICU4X::Locale.parse("en"), provider:) }

      it "raises ArgumentError for invalid unit" do
        expect { rtf.format(-1, :invalid) }
          .to raise_error(ArgumentError, /unit must be :second, :minute, :hour, :day, :week, :month, :quarter, or :year/)
      end
    end
  end

  describe "#resolved_options" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

    it "returns hash with locale, style, numeric for defaults" do
      rtf = ICU4X::RelativeTimeFormat.new(ICU4X::Locale.parse("en"), provider:)

      expect(rtf.resolved_options).to eq({locale: "en", style: :long, numeric: :always})
    end

    it "returns hash with specified style and numeric" do
      rtf = ICU4X::RelativeTimeFormat.new(
        ICU4X::Locale.parse("ja"),
        provider:,
        style: :short,
        numeric: :auto
      )

      expect(rtf.resolved_options).to eq({locale: "ja", style: :short, numeric: :auto})
    end
  end
end
