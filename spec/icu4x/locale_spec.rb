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

    it "raises LocaleError for invalid locale string" do
      expect { ICU4X::Locale.parse("!!!invalid") }.to raise_error(ICU4X::LocaleError, /Invalid locale/)
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

  describe ".parse_posix" do
    it "parses basic POSIX locale with codeset" do
      locale = ICU4X::Locale.parse_posix("ja_JP.UTF-8")

      expect(locale.language).to eq("ja")
      expect(locale.region).to eq("JP")
      expect(locale.script).to be_nil
    end

    it "parses locale without codeset" do
      locale = ICU4X::Locale.parse_posix("en_US")

      expect(locale.language).to eq("en")
      expect(locale.region).to eq("US")
    end

    it "parses locale with @latin modifier" do
      locale = ICU4X::Locale.parse_posix("sr_RS@latin")

      expect(locale.language).to eq("sr")
      expect(locale.script).to eq("Latn")
      expect(locale.region).to eq("RS")
    end

    it "parses locale with @cyrillic modifier" do
      locale = ICU4X::Locale.parse_posix("sr_RS@cyrillic")

      expect(locale.language).to eq("sr")
      expect(locale.script).to eq("Cyrl")
      expect(locale.region).to eq("RS")
    end

    it "ignores unknown modifiers" do
      locale = ICU4X::Locale.parse_posix("de_DE@euro")

      expect(locale.language).to eq("de")
      expect(locale.region).to eq("DE")
      expect(locale.script).to be_nil
    end

    it "handles C locale as undetermined" do
      locale = ICU4X::Locale.parse_posix("C")

      expect(locale.language).to be_nil
      expect(locale.to_s).to eq("und")
      expect(locale.region).to be_nil
    end

    it "handles POSIX locale as undetermined" do
      locale = ICU4X::Locale.parse_posix("POSIX")

      expect(locale.language).to be_nil
      expect(locale.to_s).to eq("und")
      expect(locale.region).to be_nil
    end

    it "parses language-only locale" do
      locale = ICU4X::Locale.parse_posix("ja")

      expect(locale.language).to eq("ja")
      expect(locale.region).to be_nil
    end

    it "handles codeset and modifier together" do
      locale = ICU4X::Locale.parse_posix("sr_RS.UTF-8@latin")

      expect(locale.language).to eq("sr")
      expect(locale.script).to eq("Latn")
      expect(locale.region).to eq("RS")
    end

    it "raises LocaleError for empty string" do
      expect { ICU4X::Locale.parse_posix("") }.to raise_error(ICU4X::LocaleError)
    end
  end
end
