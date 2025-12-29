# frozen_string_literal: true

require "pathname"

RSpec.describe ICU4X::DateTimeFormat do
  let(:fixtures_path) { Pathname.new(__dir__).parent / "fixtures" }
  let(:valid_blob_path) { fixtures_path / "test-data.postcard" }
  let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

  describe ".new" do
    let(:locale) { ICU4X::Locale.parse("en-US") }

    it "creates a DateTimeFormat instance with date_style only" do
      formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long)

      expect(formatter).to be_a(ICU4X::DateTimeFormat)
    end

    it "creates a DateTimeFormat instance with time_style only" do
      formatter = ICU4X::DateTimeFormat.new(locale, provider:, time_style: :short)

      expect(formatter).to be_a(ICU4X::DateTimeFormat)
    end

    it "creates a DateTimeFormat instance with both date_style and time_style" do
      formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, time_style: :short)

      expect(formatter).to be_a(ICU4X::DateTimeFormat)
    end

    context "with invalid arguments" do
      it "raises ArgumentError when missing provider keyword" do
        expect { ICU4X::DateTimeFormat.new(locale) }
          .to raise_error(ArgumentError, /missing keyword: :provider/)
      end

      it "raises TypeError when provider is invalid type" do
        expect { ICU4X::DateTimeFormat.new(locale, provider: "not a provider", date_style: :long) }
          .to raise_error(TypeError, /provider must be a DataProvider/)
      end

      it "raises ArgumentError when neither date_style nor time_style is specified" do
        expect { ICU4X::DateTimeFormat.new(locale, provider:) }
          .to raise_error(ArgumentError, /at least one of date_style or time_style must be specified/)
      end

      it "raises ArgumentError when date_style is invalid" do
        expect { ICU4X::DateTimeFormat.new(locale, provider:, date_style: :invalid) }
          .to raise_error(ArgumentError, /date_style must be :full, :long, :medium, or :short/)
      end

      it "raises ArgumentError when time_style is invalid" do
        expect { ICU4X::DateTimeFormat.new(locale, provider:, time_style: :invalid) }
          .to raise_error(ArgumentError, /time_style must be :full, :long, :medium, or :short/)
      end

      it "raises ArgumentError when calendar is not :gregory" do
        expect { ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :japanese) }
          .to raise_error(ArgumentError, /only :gregory calendar is currently supported/)
      end

      it "raises ArgumentError when time_zone is invalid" do
        expect { ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, time_zone: "Invalid/Timezone") }
          .to raise_error(ArgumentError, /invalid IANA timezone/)
      end
    end

    context "with valid time_zone" do
      it "creates a DateTimeFormat instance with Asia/Tokyo" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, time_zone: "Asia/Tokyo")

        expect(formatter).to be_a(ICU4X::DateTimeFormat)
      end

      it "creates a DateTimeFormat instance with America/New_York" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, time_zone: "America/New_York")

        expect(formatter).to be_a(ICU4X::DateTimeFormat)
      end
    end
  end

  describe "#format" do
    context "with en-US locale" do
      let(:locale) { ICU4X::Locale.parse("en-US") }

      it "formats date with long style" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long)

        result = formatter.format(Time.utc(2025, 12, 28))

        expect(result).to eq("December 28, 2025")
      end

      it "formats date with medium style" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :medium)

        result = formatter.format(Time.utc(2025, 12, 28))

        expect(result).to eq("Dec 28, 2025")
      end

      it "formats date with short style" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :short)

        result = formatter.format(Time.utc(2025, 12, 28))

        expect(result).to eq("12/28/25")
      end

      it "formats time with short style" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, time_style: :short)

        result = formatter.format(Time.utc(2025, 12, 28, 14, 30, 0))

        # ICU4X uses narrow no-break space (U+202F) before AM/PM
        expect(result).to eq("2:30:00\u202FPM")
      end

      it "formats date and time with both styles" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, time_style: :short)

        result = formatter.format(Time.utc(2025, 12, 28, 14, 30, 0))

        expect(result).to include("December 28, 2025")
        expect(result).to include("2:30:00\u202FPM")
      end
    end

    context "with ja-JP locale" do
      let(:locale) { ICU4X::Locale.parse("ja-JP") }

      it "formats date with long style in Japanese" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long)

        result = formatter.format(Time.utc(2025, 12, 28))

        expect(result).to eq("2025年12月28日")
      end

      it "formats date with short style in Japanese" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :short)

        result = formatter.format(Time.utc(2025, 12, 28))

        expect(result).to eq("2025/12/28")
      end
    end

    context "with de-DE locale" do
      let(:locale) { ICU4X::Locale.parse("de-DE") }

      it "formats date with long style in German" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long)

        result = formatter.format(Time.utc(2025, 12, 28))

        expect(result).to eq("28. Dezember 2025")
      end

      it "formats date with short style in German" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :short)

        result = formatter.format(Time.utc(2025, 12, 28))

        expect(result).to eq("28.12.25")
      end
    end

    context "with invalid argument" do
      let(:locale) { ICU4X::Locale.parse("en-US") }
      let(:formatter) { ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long) }

      it "raises TypeError when argument is not a Time" do
        expect { formatter.format("2025-12-28") }
          .to raise_error(TypeError, /argument must be a Time object/)
      end
    end

    context "with time_zone conversion" do
      let(:locale) { ICU4X::Locale.parse("en-US") }

      it "converts UTC to Asia/Tokyo time (+9 hours)" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, time_style: :short, time_zone: "Asia/Tokyo")

        # UTC 2025-12-28 00:00 -> Tokyo 2025-12-28 09:00
        result = formatter.format(Time.utc(2025, 12, 28, 0, 0, 0))

        expect(result).to eq("9:00:00\u202FAM")
      end

      it "converts UTC to Asia/Tokyo date when date changes" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, time_zone: "Asia/Tokyo")

        # UTC 2025-12-28 15:00 -> Tokyo 2025-12-29 00:00
        result = formatter.format(Time.utc(2025, 12, 28, 15, 0, 0))

        expect(result).to eq("December 29, 2025")
      end

      it "converts UTC to America/New_York time (-5 hours in winter)" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, time_style: :short, time_zone: "America/New_York")

        # UTC 2025-12-28 12:00 -> New York 2025-12-28 07:00 (EST, -5)
        result = formatter.format(Time.utc(2025, 12, 28, 12, 0, 0))

        expect(result).to eq("7:00:00\u202FAM")
      end

      it "formats both date and time with timezone conversion" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, time_style: :short, time_zone: "Asia/Tokyo")

        # UTC 2025-12-28 23:30 -> Tokyo 2025-12-29 08:30
        result = formatter.format(Time.utc(2025, 12, 28, 23, 30, 0))

        expect(result).to include("December 29, 2025")
        expect(result).to include("8:30:00\u202FAM")
      end
    end
  end

  describe "#resolved_options" do
    let(:locale) { ICU4X::Locale.parse("en-US") }

    it "returns locale and calendar" do
      formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long)

      expect(formatter.resolved_options).to include(
        locale: "en-US",
        calendar: :gregory
      )
    end

    it "returns date_style when specified" do
      formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long)

      expect(formatter.resolved_options).to include(date_style: :long)
    end

    it "returns time_style when specified" do
      formatter = ICU4X::DateTimeFormat.new(locale, provider:, time_style: :short)

      expect(formatter.resolved_options).to include(time_style: :short)
    end

    it "returns both date_style and time_style when both specified" do
      formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :medium, time_style: :short)

      expect(formatter.resolved_options).to include(
        date_style: :medium,
        time_style: :short
      )
    end

    it "returns time_zone when specified" do
      formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, time_zone: "Asia/Tokyo")

      expect(formatter.resolved_options).to include(time_zone: "Asia/Tokyo")
    end
  end
end
