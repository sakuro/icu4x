# frozen_string_literal: true

require "pathname"

RSpec.describe ICU4X::DurationFormat do
  let(:fixtures_path) { Pathname.new(__dir__).parent / "fixtures" }
  let(:valid_blob_path) { fixtures_path / "test-data.postcard" }

  describe ".new" do
    context "with DataProvider" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:locale) { ICU4X::Locale.parse("en") }

      it "creates with default options" do
        df = ICU4X::DurationFormat.new(locale, provider:)

        expect(df).to be_a(ICU4X::DurationFormat)
      end

      it "creates with style: :long" do
        df = ICU4X::DurationFormat.new(locale, provider:, style: :long)

        expect(df).to be_a(ICU4X::DurationFormat)
      end

      it "creates with style: :short" do
        df = ICU4X::DurationFormat.new(locale, provider:, style: :short)

        expect(df).to be_a(ICU4X::DurationFormat)
      end

      it "creates with style: :narrow" do
        df = ICU4X::DurationFormat.new(locale, provider:, style: :narrow)

        expect(df).to be_a(ICU4X::DurationFormat)
      end

      it "creates with style: :digital" do
        df = ICU4X::DurationFormat.new(locale, provider:, style: :digital)

        expect(df).to be_a(ICU4X::DurationFormat)
      end
    end

    context "with invalid arguments" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:locale) { ICU4X::Locale.parse("en") }

      it "raises ArgumentError when missing provider keyword" do
        expect { ICU4X::DurationFormat.new(locale) }
          .to raise_error(ArgumentError, /missing keyword: :provider/)
      end

      it "raises ArgumentError for invalid style" do
        expect { ICU4X::DurationFormat.new(locale, provider:, style: :invalid) }
          .to raise_error(ArgumentError, /style must be :long, :short, :narrow, or :digital/)
      end

      it "raises TypeError when provider is invalid type" do
        expect { ICU4X::DurationFormat.new(locale, provider: "not a provider") }
          .to raise_error(TypeError, /provider must be a DataProvider/)
      end
    end
  end

  describe "#format" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

    context "with style: :long (default)" do
      let(:df) { ICU4X::DurationFormat.new(ICU4X::Locale.parse("en"), provider:) }

      it "formats hours and minutes" do
        result = df.format(hours: 1, minutes: 30)

        expect(result).to include("1")
        expect(result).to include("hour")
        expect(result).to include("30")
        expect(result).to include("minute")
      end

      it "formats days, hours, and minutes" do
        result = df.format(days: 2, hours: 5, minutes: 15)

        expect(result).to include("2")
        expect(result).to include("day")
        expect(result).to include("5")
        expect(result).to include("hour")
        expect(result).to include("15")
        expect(result).to include("minute")
      end

      it "formats single unit" do
        result = df.format(seconds: 45)

        expect(result).to include("45")
        expect(result).to include("second")
      end

      it "formats years and months" do
        result = df.format(years: 1, months: 6)

        expect(result).to include("1")
        expect(result).to include("year")
        expect(result).to include("6")
        expect(result).to include("month")
      end

      it "formats weeks" do
        result = df.format(weeks: 3)

        expect(result).to include("3")
        expect(result).to include("week")
      end

      it "formats milliseconds" do
        result = df.format(milliseconds: 500)

        expect(result).to include("500")
        expect(result).to include("millisecond")
      end
    end

    context "with style: :short" do
      let(:df) { ICU4X::DurationFormat.new(ICU4X::Locale.parse("en"), provider:, style: :short) }

      it "uses abbreviated units" do
        result = df.format(hours: 2, minutes: 45)

        expect(result).to include("2")
        expect(result).to include("45")
      end
    end

    context "with style: :narrow" do
      let(:df) { ICU4X::DurationFormat.new(ICU4X::Locale.parse("en"), provider:, style: :narrow) }

      it "uses minimal format" do
        result = df.format(hours: 2, minutes: 45)

        expect(result).to include("2")
        expect(result).to include("45")
      end
    end

    context "with style: :digital" do
      let(:df) { ICU4X::DurationFormat.new(ICU4X::Locale.parse("en"), provider:, style: :digital) }

      it "formats as digital clock" do
        result = df.format(hours: 1, minutes: 30, seconds: 45)

        expect(result).to match(/1.*30.*45/)
      end
    end

    context "with Japanese locale" do
      let(:df) { ICU4X::DurationFormat.new(ICU4X::Locale.parse("ja"), provider:) }

      it "formats in Japanese" do
        result = df.format(hours: 2, minutes: 15)

        expect(result).to include("2")
        expect(result).to include("15")
      end
    end

    context "with invalid input" do
      let(:df) { ICU4X::DurationFormat.new(ICU4X::Locale.parse("en"), provider:) }

      it "raises ArgumentError for empty duration" do
        expect { df.format({}) }
          .to raise_error(ArgumentError, /duration must have at least one non-zero component/)
      end

      it "raises ArgumentError for all-zero duration" do
        expect { df.format(hours: 0, minutes: 0) }
          .to raise_error(ArgumentError, /duration must have at least one non-zero component/)
      end

      it "raises ArgumentError for negative values" do
        expect { df.format(hours: -1) }
          .to raise_error(ArgumentError, /hours must be non-negative/)
      end
    end
  end

  describe "#resolved_options" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

    it "returns hash with locale and style for defaults" do
      df = ICU4X::DurationFormat.new(ICU4X::Locale.parse("en"), provider:)

      expect(df.resolved_options).to eq({locale: "en", style: :long})
    end

    it "returns hash with specified style" do
      df = ICU4X::DurationFormat.new(
        ICU4X::Locale.parse("ja"),
        provider:,
        style: :short
      )

      expect(df.resolved_options).to eq({locale: "ja", style: :short})
    end
  end
end
