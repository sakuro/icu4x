# frozen_string_literal: true

require "pathname"

RSpec.describe ICU4X::PluralRules do
  let(:fixtures_path) { Pathname.new(__dir__).parent / "fixtures" }
  let(:valid_blob_path) { fixtures_path / "test-data.postcard" }

  describe ".new" do
    context "with DataProvider" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:locale) { ICU4X::Locale.parse("en") }

      it "creates a PluralRules instance with default type (cardinal)" do
        rules = ICU4X::PluralRules.new(locale, provider:)

        expect(rules).to be_a(ICU4X::PluralRules)
      end

      it "creates a PluralRules instance with cardinal type" do
        rules = ICU4X::PluralRules.new(locale, provider:, type: :cardinal)

        expect(rules).to be_a(ICU4X::PluralRules)
      end

      it "creates a PluralRules instance with ordinal type" do
        rules = ICU4X::PluralRules.new(locale, provider:, type: :ordinal)

        expect(rules).to be_a(ICU4X::PluralRules)
      end
    end

    context "with invalid arguments" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:locale) { ICU4X::Locale.parse("en") }

      it "raises ArgumentError when missing provider keyword" do
        expect { ICU4X::PluralRules.new(locale) }
          .to raise_error(ArgumentError, /missing keyword: :provider/)
      end

      it "raises ArgumentError when type is invalid" do
        expect { ICU4X::PluralRules.new(locale, provider:, type: :invalid) }
          .to raise_error(ArgumentError, /type must be :cardinal or :ordinal/)
      end

      it "raises TypeError when provider is invalid type" do
        expect { ICU4X::PluralRules.new(locale, provider: "not a provider") }
          .to raise_error(TypeError, /provider must be a DataProvider/)
      end
    end
  end

  describe "#select" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

    context "with English (en) - cardinal" do
      let(:rules) { ICU4X::PluralRules.new(ICU4X::Locale.parse("en"), provider:, type: :cardinal) }

      it "returns :one for 1" do
        expect(rules.select(1)).to eq(:one)
      end

      it "returns :other for 0" do
        expect(rules.select(0)).to eq(:other)
      end

      it "returns :other for 2" do
        expect(rules.select(2)).to eq(:other)
      end

      it "returns :other for 10" do
        expect(rules.select(10)).to eq(:other)
      end
    end

    context "with English (en) - ordinal" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:rules) { ICU4X::PluralRules.new(ICU4X::Locale.parse("en"), provider:, type: :ordinal) }

      it "returns :one for 1 (1st)" do
        expect(rules.select(1)).to eq(:one)
      end

      it "returns :two for 2 (2nd)" do
        expect(rules.select(2)).to eq(:two)
      end

      it "returns :few for 3 (3rd)" do
        expect(rules.select(3)).to eq(:few)
      end

      it "returns :other for 4 (4th)" do
        expect(rules.select(4)).to eq(:other)
      end

      it "returns :other for 11 (11th)" do
        expect(rules.select(11)).to eq(:other)
      end

      it "returns :one for 21 (21st)" do
        expect(rules.select(21)).to eq(:one)
      end
    end

    context "with Japanese (ja)" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:rules) { ICU4X::PluralRules.new(ICU4X::Locale.parse("ja"), provider:, type: :cardinal) }

      it "returns :other for all numbers" do
        [0, 1, 2, 5, 10, 100].each do |n|
          expect(rules.select(n)).to eq(:other)
        end
      end
    end

    context "with Russian (ru) - cardinal" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:rules) { ICU4X::PluralRules.new(ICU4X::Locale.parse("ru"), provider:, type: :cardinal) }

      it "returns :one for 1" do
        expect(rules.select(1)).to eq(:one)
      end

      it "returns :one for 21" do
        expect(rules.select(21)).to eq(:one)
      end

      it "returns :few for 2" do
        expect(rules.select(2)).to eq(:few)
      end

      it "returns :few for 3" do
        expect(rules.select(3)).to eq(:few)
      end

      it "returns :few for 4" do
        expect(rules.select(4)).to eq(:few)
      end

      it "returns :many for 5" do
        expect(rules.select(5)).to eq(:many)
      end

      it "returns :many for 11" do
        expect(rules.select(11)).to eq(:many)
      end

      it "returns :many for 0" do
        expect(rules.select(0)).to eq(:many)
      end
    end

    context "with Arabic (ar) - cardinal" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:rules) { ICU4X::PluralRules.new(ICU4X::Locale.parse("ar"), provider:, type: :cardinal) }

      it "returns :zero for 0" do
        expect(rules.select(0)).to eq(:zero)
      end

      it "returns :one for 1" do
        expect(rules.select(1)).to eq(:one)
      end

      it "returns :two for 2" do
        expect(rules.select(2)).to eq(:two)
      end

      it "returns :few for 3" do
        expect(rules.select(3)).to eq(:few)
      end

      it "returns :few for 10" do
        expect(rules.select(10)).to eq(:few)
      end

      it "returns :many for 11" do
        expect(rules.select(11)).to eq(:many)
      end

      it "returns :many for 99" do
        expect(rules.select(99)).to eq(:many)
      end

      it "returns :other for 100" do
        expect(rules.select(100)).to eq(:other)
      end
    end

    context "with floats" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:rules) { ICU4X::PluralRules.new(ICU4X::Locale.parse("en"), provider:, type: :cardinal) }

      it "handles float values" do
        expect(rules.select(1.5)).to eq(:other)
      end
    end

    context "with invalid number" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:rules) { ICU4X::PluralRules.new(ICU4X::Locale.parse("en"), provider:) }

      it "raises TypeError for string" do
        expect { rules.select("one") }.to raise_error(TypeError, /number must be an Integer or Float/)
      end
    end
  end

  describe "#categories" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

    it "returns available categories for English cardinal" do
      rules = ICU4X::PluralRules.new(ICU4X::Locale.parse("en"), provider:, type: :cardinal)

      expect(rules.categories).to contain_exactly(:one, :other)
    end

    it "returns available categories for Japanese cardinal" do
      provider = ICU4X::DataProvider.from_blob(valid_blob_path)
      rules = ICU4X::PluralRules.new(ICU4X::Locale.parse("ja"), provider:, type: :cardinal)

      expect(rules.categories).to contain_exactly(:other)
    end

    it "returns available categories for Russian cardinal" do
      provider = ICU4X::DataProvider.from_blob(valid_blob_path)
      rules = ICU4X::PluralRules.new(ICU4X::Locale.parse("ru"), provider:, type: :cardinal)

      expect(rules.categories).to contain_exactly(:one, :few, :many, :other)
    end

    it "returns available categories for Arabic cardinal" do
      provider = ICU4X::DataProvider.from_blob(valid_blob_path)
      rules = ICU4X::PluralRules.new(ICU4X::Locale.parse("ar"), provider:, type: :cardinal)

      expect(rules.categories).to contain_exactly(:zero, :one, :two, :few, :many, :other)
    end
  end

  describe "#resolved_options" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

    it "returns locale and type for cardinal" do
      rules = ICU4X::PluralRules.new(ICU4X::Locale.parse("en"), provider:, type: :cardinal)

      expect(rules.resolved_options).to eq({locale: "en", type: :cardinal})
    end

    it "returns locale and type for ordinal" do
      provider = ICU4X::DataProvider.from_blob(valid_blob_path)
      rules = ICU4X::PluralRules.new(ICU4X::Locale.parse("ja"), provider:, type: :ordinal)

      expect(rules.resolved_options).to eq({locale: "ja", type: :ordinal})
    end
  end
end
