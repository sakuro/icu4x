# frozen_string_literal: true

RSpec.describe ICU4X::Locale do
  describe ".parse" do
    it "parses a simple language code" do
      locale = ICU4X::Locale.parse("en")

      expect(locale.language).to eq("en")
      expect(locale.script).to be_nil
      expect(locale.region).to be_nil
    end

    it "parses language-region format" do
      locale = ICU4X::Locale.parse("ja-JP")

      expect(locale.language).to eq("ja")
      expect(locale.region).to eq("JP")
      expect(locale.script).to be_nil
    end

    it "parses language-script-region format" do
      locale = ICU4X::Locale.parse("zh-Hans-CN")

      expect(locale.language).to eq("zh")
      expect(locale.script).to eq("Hans")
      expect(locale.region).to eq("CN")
    end

    it "raises ArgumentError for invalid locale string" do
      expect { ICU4X::Locale.parse("!!!invalid") }.to raise_error(ArgumentError, /Invalid locale/)
    end
  end

  describe "#to_s" do
    it "returns the string representation" do
      locale = ICU4X::Locale.parse("en-US")

      expect(locale.to_s).to eq("en-US")
    end
  end

  describe "#inspect" do
    it "returns a human-readable representation" do
      locale = ICU4X::Locale.parse("ja-JP")

      expect(locale.inspect).to eq("#<ICU4X::Locale:ja-JP>")
    end
  end

  describe "#==" do
    it "returns true for equal locales" do
      locale1 = ICU4X::Locale.parse("en-US")
      locale2 = ICU4X::Locale.parse("en-US")

      expect(locale1).to eq(locale2)
    end

    it "returns false for different locales" do
      locale1 = ICU4X::Locale.parse("en-US")
      locale2 = ICU4X::Locale.parse("en-GB")

      expect(locale1).not_to eq(locale2)
    end
  end

  describe "hash key support" do
    it "can be used as a Hash key" do
      locale = ICU4X::Locale.parse("en-US")
      hash = {locale => "value"}

      expect(hash[ICU4X::Locale.parse("en-US")]).to eq("value")
    end

    it "returns same hash for equal locales" do
      locale1 = ICU4X::Locale.parse("ja-JP")
      locale2 = ICU4X::Locale.parse("ja-JP")

      expect(locale1.hash).to eq(locale2.hash)
    end
  end

  describe "#extensions" do
    it "returns Unicode extensions as a hash" do
      locale = ICU4X::Locale.parse("ja-JP-u-ca-japanese-nu-jpan")

      expect(locale.extensions[:unicode]).to eq({"ca" => "japanese", "nu" => "jpan"})
    end

    it "returns empty unicode hash when no extensions" do
      locale = ICU4X::Locale.parse("en-US")

      expect(locale.extensions[:unicode]).to eq({})
    end

    it "returns nil for transform when not present" do
      locale = ICU4X::Locale.parse("en-US")

      expect(locale.extensions[:transform]).to be_nil
    end

    it "returns empty array for private when not present" do
      locale = ICU4X::Locale.parse("en-US")

      expect(locale.extensions[:private]).to eq([])
    end

    it "returns private use extensions" do
      locale = ICU4X::Locale.parse("en-US-x-custom")

      expect(locale.extensions[:private]).to eq(["custom"])
    end
  end
end
