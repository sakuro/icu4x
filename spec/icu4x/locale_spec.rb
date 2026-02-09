# frozen_string_literal: true

RSpec.describe ICU4X::Locale do
  describe ".parse_bcp47" do
    it "parses a simple language code" do
      locale = ICU4X::Locale.parse_bcp47("en")

      expect(locale.language).to eq("en")
      expect(locale.script).to be_nil
      expect(locale.region).to be_nil
    end

    it "parses language-region format" do
      locale = ICU4X::Locale.parse_bcp47("ja-JP")

      expect(locale.language).to eq("ja")
      expect(locale.region).to eq("JP")
      expect(locale.script).to be_nil
    end

    it "parses language-script-region format" do
      locale = ICU4X::Locale.parse_bcp47("zh-Hans-CN")

      expect(locale.language).to eq("zh")
      expect(locale.script).to eq("Hans")
      expect(locale.region).to eq("CN")
    end

    it "raises LocaleError for invalid locale string" do
      expect { ICU4X::Locale.parse_bcp47("!!!invalid") }.to raise_error(ICU4X::LocaleError, /Invalid locale/)
    end
  end

  describe ".parse" do
    it "is an alias for .parse_bcp47" do
      expect(ICU4X::Locale.method(:parse).original_name).to eq(:parse_bcp47)
    end

    it "parses BCP 47 locale string" do
      locale = ICU4X::Locale.parse("ja-JP")

      expect(locale.language).to eq("ja")
      expect(locale.region).to eq("JP")
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

  describe ".from_env" do
    around do |example|
      original = ENV.to_h.slice("LC_ALL", "LC_MESSAGES", "LC_COLLATE", "LANG")
      ENV.delete("LC_ALL")
      ENV.delete("LC_MESSAGES")
      ENV.delete("LC_COLLATE")
      ENV.delete("LANG")
      example.run
    ensure
      original.each {|key, value| ENV[key] = value }
    end

    it "returns locale from LC_ALL when set" do
      ENV["LC_ALL"] = "ja_JP.UTF-8"
      locale = ICU4X::Locale.from_env
      expect(locale.language).to eq("ja")
      expect(locale.region).to eq("JP")
    end

    it "returns locale from LC_{category} when LC_ALL is not set" do
      ENV["LC_MESSAGES"] = "fr_FR.UTF-8"
      locale = ICU4X::Locale.from_env
      expect(locale.language).to eq("fr")
      expect(locale.region).to eq("FR")
    end

    it "returns locale from LANG as last resort" do
      ENV["LANG"] = "de_DE.UTF-8"
      locale = ICU4X::Locale.from_env
      expect(locale.language).to eq("de")
      expect(locale.region).to eq("DE")
    end

    it "prefers LC_ALL over LC_{category} and LANG" do
      ENV["LC_ALL"] = "ja_JP.UTF-8"
      ENV["LC_MESSAGES"] = "fr_FR.UTF-8"
      ENV["LANG"] = "de_DE.UTF-8"
      locale = ICU4X::Locale.from_env
      expect(locale.language).to eq("ja")
    end

    it "prefers LC_{category} over LANG" do
      ENV["LC_MESSAGES"] = "fr_FR.UTF-8"
      ENV["LANG"] = "de_DE.UTF-8"
      locale = ICU4X::Locale.from_env
      expect(locale.language).to eq("fr")
    end

    it "uses the specified category" do
      ENV["LC_COLLATE"] = "es_ES.UTF-8"
      locale = ICU4X::Locale.from_env(category: :collate)
      expect(locale.language).to eq("es")
      expect(locale.region).to eq("ES")
    end

    it "falls back to C locale when no environment variables are set" do
      locale = ICU4X::Locale.from_env
      expect(locale.to_s).to eq("und")
    end

    it "skips unparseable values and tries next" do
      ENV["LC_ALL"] = "invalid@@locale"
      ENV["LC_MESSAGES"] = "fr_FR.UTF-8"
      locale = ICU4X::Locale.from_env
      expect(locale.language).to eq("fr")
    end

    it "skips nil values" do
      ENV["LANG"] = "fr_FR.UTF-8"
      locale = ICU4X::Locale.from_env
      expect(locale.language).to eq("fr")
    end

    it "skips empty values" do
      ENV["LC_ALL"] = ""
      ENV["LC_MESSAGES"] = "fr_FR.UTF-8"
      locale = ICU4X::Locale.from_env
      expect(locale.language).to eq("fr")
    end

    it "raises ArgumentError for unknown category" do
      expect { ICU4X::Locale.from_env(category: :unknown) }.to raise_error(ArgumentError, /unknown locale category/)
    end
  end

  describe "#maximize!" do
    it "expands language to full locale and returns self" do
      locale = ICU4X::Locale.parse("en")

      expect(locale.maximize!).to be(locale)
      expect(locale.to_s).to eq("en-Latn-US")
    end

    it "expands zh to zh-Hans-CN" do
      locale = ICU4X::Locale.parse("zh")

      expect(locale.maximize!).to be(locale)
      expect(locale.to_s).to eq("zh-Hans-CN")
    end

    it "expands ja to ja-Jpan-JP" do
      locale = ICU4X::Locale.parse("ja")

      expect(locale.maximize!).to be(locale)
      expect(locale.to_s).to eq("ja-Jpan-JP")
    end

    it "returns nil when already maximized" do
      locale = ICU4X::Locale.parse("en-Latn-US")

      expect(locale.maximize!).to be_nil
      expect(locale.to_s).to eq("en-Latn-US")
    end

    it "handles script inference" do
      locale = ICU4X::Locale.parse("sr-Latn")

      locale.maximize!

      expect(locale.region).to eq("RS")
    end
  end

  describe "#maximize" do
    it "returns a new maximized locale" do
      locale = ICU4X::Locale.parse("en")

      result = locale.maximize

      expect(result).not_to be(locale)
      expect(result.to_s).to eq("en-Latn-US")
      expect(locale.to_s).to eq("en")
    end

    it "returns a new object even when already maximized" do
      locale = ICU4X::Locale.parse("en-Latn-US")

      result = locale.maximize

      expect(result).not_to be(locale)
      expect(result.to_s).to eq("en-Latn-US")
    end
  end

  describe "#minimize!" do
    it "removes redundant subtags and returns self" do
      locale = ICU4X::Locale.parse("zh-Hans-CN")

      expect(locale.minimize!).to be(locale)
      expect(locale.to_s).to eq("zh")
    end

    it "keeps necessary subtags" do
      # sr-Latn needs script since sr defaults to Cyrillic
      locale = ICU4X::Locale.parse("sr-Latn")

      locale.minimize!

      expect(locale.script).to eq("Latn")
    end

    it "returns nil when already minimal" do
      locale = ICU4X::Locale.parse("en")

      expect(locale.minimize!).to be_nil
      expect(locale.to_s).to eq("en")
    end
  end

  describe "#minimize" do
    it "returns a new minimized locale" do
      locale = ICU4X::Locale.parse("zh-Hans-CN")

      result = locale.minimize

      expect(result).not_to be(locale)
      expect(result.to_s).to eq("zh")
      expect(locale.to_s).to eq("zh-Hans-CN")
    end

    it "returns a new object even when already minimal" do
      locale = ICU4X::Locale.parse("en")

      result = locale.minimize

      expect(result).not_to be(locale)
      expect(result.to_s).to eq("en")
    end
  end
end
