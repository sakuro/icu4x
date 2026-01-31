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
        rtf = ICU4X::RelativeTimeFormat.new(locale)
        expect(rtf.format(-1, :day)).to eq("1 day ago")
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
        expect { ICU4X::RelativeTimeFormat.new(locale) }
          .to raise_error(ArgumentError, /No provider specified and no default configured/)
      end

      it "raises ArgumentError for invalid style" do
        expect { ICU4X::RelativeTimeFormat.new(locale, provider:, style: :invalid) }
          .to raise_error(ArgumentError, /style must be :long, :short, :narrow/)
      end

      it "raises ArgumentError for invalid numeric" do
        expect { ICU4X::RelativeTimeFormat.new(locale, provider:, numeric: :invalid) }
          .to raise_error(ArgumentError, /numeric must be :always, :auto/)
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
          .to raise_error(ArgumentError, /unit must be :second, :minute, :hour, :day, :week, :month, :quarter, :year/)
      end
    end
  end

  describe "#format with numbering system" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

    context "with Han decimal numerals (hanidec)" do
      let(:locale) { ICU4X::Locale.parse("ja-u-nu-hanidec") }
      let(:rtf) { ICU4X::RelativeTimeFormat.new(locale, provider:) }

      it "formats using Han decimal numerals" do
        result = rtf.format(-3, :day)

        expect(result).to eq("三 日前")
      end

      it "includes numbering system in resolved_options locale" do
        expect(rtf.resolved_options[:locale]).to eq("ja-u-nu-hanidec")
      end
    end

    context "with Arabic-Indic numerals (arab)" do
      let(:locale) { ICU4X::Locale.parse("ar-u-nu-arab") }
      let(:rtf) { ICU4X::RelativeTimeFormat.new(locale, provider:) }

      it "formats using Arabic-Indic numerals" do
        result = rtf.format(-3, :day)

        expect(result).to include("٣")
      end
    end
  end

  describe "#format_to_parts" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
    let(:locale) { ICU4X::Locale.parse("en") }
    let(:rtf) { ICU4X::RelativeTimeFormat.new(locale, provider:) }

    it "returns an array of FormattedPart" do
      parts = rtf.format_to_parts(-3, :day)

      expect(parts).to all(be_a(ICU4X::FormattedPart))
    end

    # NOTE: ICU4X experimental RelativeTimeFormatter does not provide separate
    # part annotations for the numeric value. The entire formatted string is
    # returned as a single :literal part.
    it "returns literal part for past time" do
      parts = rtf.format_to_parts(-3, :day)

      expect(parts.map(&:type)).to eq([:literal])
      expect(parts.map(&:value)).to eq(["3 days ago"])
    end

    it "returns literal part for future time" do
      parts = rtf.format_to_parts(2, :hour)

      expect(parts.map(&:type)).to eq([:literal])
      expect(parts.map(&:value)).to eq(["in 2 hours"])
    end

    it "can reconstruct formatted string from parts" do
      value = -5
      unit = :minute
      parts = rtf.format_to_parts(value, unit)

      expect(parts.map(&:value).join).to eq(rtf.format(value, unit))
    end

    context "with numeric: :auto" do
      let(:rtf) { ICU4X::RelativeTimeFormat.new(locale, provider:, numeric: :auto) }

      it "returns single literal part for yesterday" do
        parts = rtf.format_to_parts(-1, :day)

        expect(parts.map(&:type)).to eq([:literal])
        expect(parts.map(&:value)).to eq(["yesterday"])
      end

      it "returns single literal part for today" do
        parts = rtf.format_to_parts(0, :day)

        expect(parts.map(&:type)).to eq([:literal])
        expect(parts.map(&:value)).to eq(["today"])
      end

      it "returns single literal part for tomorrow" do
        parts = rtf.format_to_parts(1, :day)

        expect(parts.map(&:type)).to eq([:literal])
        expect(parts.map(&:value)).to eq(["tomorrow"])
      end

      it "returns single literal part for larger values" do
        parts = rtf.format_to_parts(-2, :day)

        expect(parts.map(&:type)).to eq([:literal])
        expect(parts.map(&:value)).to eq(["2 days ago"])
      end
    end

    context "with invalid unit" do
      it "raises ArgumentError for invalid unit" do
        expect { rtf.format_to_parts(-1, :invalid) }
          .to raise_error(ArgumentError, /unit must be :second, :minute, :hour, :day, :week, :month, :quarter, :year/)
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
