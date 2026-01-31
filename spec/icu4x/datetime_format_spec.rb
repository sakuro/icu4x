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

    context "with optional provider" do
      around do |example|
        original_env = ENV.fetch("ICU4X_DATA_PATH", nil)
        ENV["ICU4X_DATA_PATH"] = valid_blob_path.to_s
        example.run
      ensure
        ENV["ICU4X_DATA_PATH"] = original_env
      end

      it "uses default provider when provider is not specified" do
        formatter = ICU4X::DateTimeFormat.new(locale, date_style: :short)
        expect(formatter.format(Time.utc(2024, 1, 15))).to include("1/15/24")
      end
    end

    context "with invalid arguments" do
      around do |example|
        original_env = ENV.fetch("ICU4X_DATA_PATH", nil)
        ENV.delete("ICU4X_DATA_PATH")
        example.run
      ensure
        ENV["ICU4X_DATA_PATH"] = original_env
      end

      it "raises ArgumentError when no provider is available" do
        expect { ICU4X::DateTimeFormat.new(locale, date_style: :long) }
          .to raise_error(ArgumentError, /No provider specified and no default configured/)
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
          .to raise_error(ArgumentError, /date_style must be :full, :long, :medium, :short/)
      end

      it "raises ArgumentError when time_style is invalid" do
        expect { ICU4X::DateTimeFormat.new(locale, provider:, time_style: :invalid) }
          .to raise_error(ArgumentError, /time_style must be :full, :long, :medium, :short/)
      end

      it "raises ArgumentError when calendar is invalid" do
        expect { ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :invalid) }
          .to raise_error(ArgumentError, /calendar must be/)
      end

      it "raises ArgumentError when time_zone is invalid" do
        expect { ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, time_zone: "Invalid/Timezone") }
          .to raise_error(ArgumentError, /invalid IANA timezone/)
      end

      it "raises ArgumentError when hour_cycle is invalid" do
        expect { ICU4X::DateTimeFormat.new(locale, provider:, time_style: :short, hour_cycle: :h24) }
          .to raise_error(ArgumentError, /hour_cycle must be :h11, :h12, :h23/)
      end
    end

    context "with hour_cycle option" do
      it "creates a DateTimeFormat instance with hour_cycle: :h12" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, time_style: :short, hour_cycle: :h12)

        expect(formatter).to be_a(ICU4X::DateTimeFormat)
      end

      it "creates a DateTimeFormat instance with hour_cycle: :h23" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, time_style: :short, hour_cycle: :h23)

        expect(formatter).to be_a(ICU4X::DateTimeFormat)
      end

      it "creates a DateTimeFormat instance with hour_cycle: :h11" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, time_style: :short, hour_cycle: :h11)

        expect(formatter).to be_a(ICU4X::DateTimeFormat)
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

    context "with Date object" do
      let(:locale) { ICU4X::Locale.parse("en-US") }

      it "formats Date by calling #to_time" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, time_zone: "Asia/Tokyo")

        result = formatter.format(Date.new(2025, 12, 28))

        expect(result).to eq("December 28, 2025")
      end
    end

    context "with invalid argument" do
      let(:locale) { ICU4X::Locale.parse("en-US") }
      let(:formatter) { ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long) }

      it "raises TypeError when argument does not respond to #to_time" do
        expect { formatter.format("2025-12-28") }
          .to raise_error(TypeError, /argument must be a Time object or respond to #to_time/)
      end
    end

    context "with hour_cycle option" do
      let(:locale) { ICU4X::Locale.parse("en-US") }
      let(:midnight) { Time.utc(2025, 12, 28, 0, 30, 0) }
      let(:noon) { Time.utc(2025, 12, 28, 12, 30, 0) }

      it "formats midnight with h12 as 12:30 AM" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, time_style: :short, hour_cycle: :h12)

        result = formatter.format(midnight)

        expect(result).to eq("12:30:00\u202FAM")
      end

      it "formats midnight with h23 as 00:30" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, time_style: :short, hour_cycle: :h23)

        result = formatter.format(midnight)

        expect(result).to eq("00:30:00")
      end

      it "formats midnight with h11 as 0:30 AM" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, time_style: :short, hour_cycle: :h11)

        result = formatter.format(midnight)

        expect(result).to eq("0:30:00\u202FAM")
      end

      it "formats noon with h12 as 12:30 PM" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, time_style: :short, hour_cycle: :h12)

        result = formatter.format(noon)

        expect(result).to eq("12:30:00\u202FPM")
      end

      it "formats noon with h23 as 12:30" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, time_style: :short, hour_cycle: :h23)

        result = formatter.format(noon)

        expect(result).to eq("12:30:00")
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

  describe "#format with numbering system" do
    context "with Han decimal numerals (hanidec)" do
      let(:locale) { ICU4X::Locale.parse("ja-JP-u-nu-hanidec") }
      let(:formatter) { ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long) }

      it "formats date using Han decimal numerals" do
        result = formatter.format(Time.utc(2025, 12, 28))

        expect(result).to eq("二〇二五年一二月二八日")
      end

      it "includes numbering system in resolved_options locale" do
        expect(formatter.resolved_options[:locale]).to eq("ja-JP-u-nu-hanidec")
      end
    end

    context "with Thai numerals (thai)" do
      let(:locale) { ICU4X::Locale.parse("th-TH-u-nu-thai") }
      let(:formatter) { ICU4X::DateTimeFormat.new(locale, provider:, date_style: :short) }

      it "formats date using Thai numerals" do
        result = formatter.format(Time.utc(2025, 12, 28))

        expect(result).to include("๒๘")
      end
    end
  end

  describe "#format_to_parts" do
    context "with en-US locale and date_style" do
      let(:locale) { ICU4X::Locale.parse("en-US") }
      let(:formatter) { ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long) }
      let(:time) { Time.utc(2025, 1, 31, 15, 30, 45) }

      it "returns an array of FormattedPart objects" do
        parts = formatter.format_to_parts(time)

        expect(parts).to be_an(Array)
        expect(parts).to all(be_a(ICU4X::FormattedPart))
      end

      it "includes month, day, and year parts" do
        parts = formatter.format_to_parts(time)
        types = parts.map(&:type)

        expect(types).to include(:month, :day, :year)
      end

      it "includes literal separators" do
        parts = formatter.format_to_parts(time)
        literals = parts.select {|p| p.type == :literal }

        expect(literals).not_to be_empty
      end

      it "reconstructs the formatted string when joined" do
        parts = formatter.format_to_parts(time)
        joined = parts.map(&:value).join

        expect(joined).to eq(formatter.format(time))
      end
    end

    context "with date and time styles" do
      let(:locale) { ICU4X::Locale.parse("en-US") }
      let(:formatter) { ICU4X::DateTimeFormat.new(locale, provider:, date_style: :medium, time_style: :medium) }
      let(:time) { Time.utc(2025, 1, 31, 15, 30, 45) }

      it "includes hour, minute, second, and day_period parts" do
        parts = formatter.format_to_parts(time)
        types = parts.map(&:type)

        expect(types).to include(:hour, :minute, :second, :day_period)
      end
    end

    context "with Japanese calendar" do
      let(:locale) { ICU4X::Locale.parse("ja-JP") }
      let(:formatter) { ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :japanese) }
      let(:time) { Time.utc(2025, 1, 31) }

      it "includes era part" do
        parts = formatter.format_to_parts(time)
        types = parts.map(&:type)

        expect(types).to include(:era)
      end

      it "has era value of 令和" do
        parts = formatter.format_to_parts(time)
        era_part = parts.find {|p| p.type == :era }

        expect(era_part.value).to eq("令和")
      end
    end

    context "with Date object" do
      let(:locale) { ICU4X::Locale.parse("en-US") }
      let(:formatter) { ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, time_zone: "Asia/Tokyo") }

      it "formats Date by calling #to_time" do
        parts = formatter.format_to_parts(Date.new(2025, 12, 28))
        joined = parts.map(&:value).join

        expect(joined).to eq("December 28, 2025")
      end
    end

    context "with invalid argument" do
      let(:locale) { ICU4X::Locale.parse("en-US") }
      let(:formatter) { ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long) }

      it "raises TypeError when argument does not respond to #to_time" do
        expect { formatter.format_to_parts("2025-12-28") }
          .to raise_error(TypeError, /argument must be a Time object or respond to #to_time/)
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

    it "returns specified calendar" do
      formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :japanese)

      expect(formatter.resolved_options).to include(calendar: :japanese)
    end

    it "returns hour_cycle when specified" do
      formatter = ICU4X::DateTimeFormat.new(locale, provider:, time_style: :short, hour_cycle: :h23)

      expect(formatter.resolved_options).to include(hour_cycle: :h23)
    end

    it "does not return hour_cycle when not specified" do
      formatter = ICU4X::DateTimeFormat.new(locale, provider:, time_style: :short)

      expect(formatter.resolved_options).not_to have_key(:hour_cycle)
    end
  end

  describe "calendar support" do
    let(:locale) { ICU4X::Locale.parse("en-US") }
    let(:test_time) { Time.utc(2025, 12, 28) }

    context "with :japanese calendar" do
      it "creates formatter with Japanese calendar" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :japanese)

        expect(formatter).to be_a(ICU4X::DateTimeFormat)
        expect(formatter.resolved_options[:calendar]).to eq(:japanese)
      end

      it "formats date in Japanese era" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :japanese)

        result = formatter.format(test_time)

        expect(result).to include("Reiwa")
      end
    end

    context "with :buddhist calendar" do
      it "creates formatter with Buddhist calendar" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :buddhist)

        expect(formatter).to be_a(ICU4X::DateTimeFormat)
        expect(formatter.resolved_options[:calendar]).to eq(:buddhist)
      end

      it "formats date in Buddhist era (BE 2568 for 2025 CE)" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :buddhist)

        result = formatter.format(test_time)

        expect(result).to include("2568")
      end
    end

    context "with :hebrew calendar" do
      it "creates formatter with Hebrew calendar" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :hebrew)

        expect(formatter).to be_a(ICU4X::DateTimeFormat)
        expect(formatter.resolved_options[:calendar]).to eq(:hebrew)
      end
    end

    context "with :chinese calendar" do
      it "creates formatter with Chinese calendar" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :chinese)

        expect(formatter).to be_a(ICU4X::DateTimeFormat)
        expect(formatter.resolved_options[:calendar]).to eq(:chinese)
      end
    end

    context "with :coptic calendar" do
      it "creates formatter with Coptic calendar" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :coptic)

        expect(formatter).to be_a(ICU4X::DateTimeFormat)
        expect(formatter.resolved_options[:calendar]).to eq(:coptic)
      end
    end

    context "with :ethiopian calendar" do
      it "creates formatter with Ethiopian calendar" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :ethiopian)

        expect(formatter).to be_a(ICU4X::DateTimeFormat)
        expect(formatter.resolved_options[:calendar]).to eq(:ethiopian)
      end
    end

    context "with :indian calendar" do
      it "creates formatter with Indian calendar" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :indian)

        expect(formatter).to be_a(ICU4X::DateTimeFormat)
        expect(formatter.resolved_options[:calendar]).to eq(:indian)
      end
    end

    context "with :islamic calendar" do
      it "creates formatter with Islamic calendar" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :islamic)

        expect(formatter).to be_a(ICU4X::DateTimeFormat)
        expect(formatter.resolved_options[:calendar]).to eq(:islamic)
      end
    end

    context "with :persian calendar" do
      it "creates formatter with Persian calendar" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :persian)

        expect(formatter).to be_a(ICU4X::DateTimeFormat)
        expect(formatter.resolved_options[:calendar]).to eq(:persian)
      end
    end

    context "with :roc calendar" do
      it "creates formatter with ROC calendar" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :roc)

        expect(formatter).to be_a(ICU4X::DateTimeFormat)
        expect(formatter.resolved_options[:calendar]).to eq(:roc)
      end

      it "formats date in ROC era (114 for 2025 CE)" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :roc)

        result = formatter.format(test_time)

        expect(result).to include("114")
      end
    end

    context "with :dangi calendar" do
      it "creates formatter with Dangi calendar" do
        formatter = ICU4X::DateTimeFormat.new(locale, provider:, date_style: :long, calendar: :dangi)

        expect(formatter).to be_a(ICU4X::DateTimeFormat)
        expect(formatter.resolved_options[:calendar]).to eq(:dangi)
      end
    end
  end
end
