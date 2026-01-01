# frozen_string_literal: true

require "pathname"

RSpec.describe ICU4X::DisplayNames do
  let(:fixtures_path) { Pathname.new(__dir__).parent / "fixtures" }
  let(:valid_blob_path) { fixtures_path / "test-data.postcard" }

  describe ".new" do
    context "with DataProvider" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:locale) { ICU4X::Locale.parse("ja") }

      it "creates a DisplayNames instance with type: :language" do
        dn = ICU4X::DisplayNames.new(locale, provider:, type: :language)

        expect(dn).to be_a(ICU4X::DisplayNames)
      end

      it "creates a DisplayNames instance with type: :region" do
        dn = ICU4X::DisplayNames.new(locale, provider:, type: :region)

        expect(dn).to be_a(ICU4X::DisplayNames)
      end

      it "creates a DisplayNames instance with type: :script" do
        dn = ICU4X::DisplayNames.new(locale, provider:, type: :script)

        expect(dn).to be_a(ICU4X::DisplayNames)
      end

      it "creates a DisplayNames instance with type: :locale" do
        dn = ICU4X::DisplayNames.new(locale, provider:, type: :locale)

        expect(dn).to be_a(ICU4X::DisplayNames)
      end

      it "creates a DisplayNames instance with style: :short" do
        dn = ICU4X::DisplayNames.new(locale, provider:, type: :language, style: :short)

        expect(dn).to be_a(ICU4X::DisplayNames)
      end

      it "creates a DisplayNames instance with style: :narrow" do
        dn = ICU4X::DisplayNames.new(locale, provider:, type: :language, style: :narrow)

        expect(dn).to be_a(ICU4X::DisplayNames)
      end

      it "creates a DisplayNames instance with fallback: :none" do
        dn = ICU4X::DisplayNames.new(locale, provider:, type: :language, fallback: :none)

        expect(dn).to be_a(ICU4X::DisplayNames)
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
        dn = ICU4X::DisplayNames.new(locale, type: :language)
        expect(dn.of("ja")).to eq("Japanese")
      end
    end

    context "with invalid arguments" do
      let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }
      let(:locale) { ICU4X::Locale.parse("ja") }

      around do |example|
        original_env = ENV.fetch("ICU4X_DATA_PATH", nil)
        ENV.delete("ICU4X_DATA_PATH")
        example.run
      ensure
        ENV["ICU4X_DATA_PATH"] = original_env
      end

      it "raises ArgumentError when no provider is available" do
        expect { ICU4X::DisplayNames.new(locale, type: :language) }
          .to raise_error(ArgumentError, /No provider specified and no default configured/)
      end

      it "raises ArgumentError when missing type keyword" do
        expect { ICU4X::DisplayNames.new(locale, provider:) }
          .to raise_error(ArgumentError, /missing keyword: :type/)
      end

      it "raises ArgumentError when type is invalid" do
        expect { ICU4X::DisplayNames.new(locale, provider:, type: :invalid) }
          .to raise_error(ArgumentError, /type must be :language, :region, :script, :locale/)
      end

      it "raises ArgumentError when style is invalid" do
        expect { ICU4X::DisplayNames.new(locale, provider:, type: :language, style: :invalid) }
          .to raise_error(ArgumentError, /style must be :long, :short, :narrow/)
      end

      it "raises ArgumentError when fallback is invalid" do
        expect { ICU4X::DisplayNames.new(locale, provider:, type: :language, fallback: :invalid) }
          .to raise_error(ArgumentError, /fallback must be :code, :none/)
      end

      it "raises TypeError when provider is invalid type" do
        expect { ICU4X::DisplayNames.new(locale, provider: "not a provider", type: :language) }
          .to raise_error(TypeError, /provider must be a DataProvider/)
      end
    end
  end

  describe "#of" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

    context "with type: :language" do
      let(:dn) { ICU4X::DisplayNames.new(ICU4X::Locale.parse("ja"), provider:, type: :language) }

      it "returns display name for known language code 'en'" do
        expect(dn.of("en")).to eq("英語")
      end

      it "returns display name for known language code 'ja'" do
        expect(dn.of("ja")).to eq("日本語")
      end

      it "returns display name for known language code 'de'" do
        expect(dn.of("de")).to eq("ドイツ語")
      end

      it "returns code for unknown code with fallback: :code" do
        expect(dn.of("xyz")).to eq("xyz")
      end
    end

    context "with type: :language and fallback: :none" do
      let(:dn) { ICU4X::DisplayNames.new(ICU4X::Locale.parse("ja"), provider:, type: :language, fallback: :none) }

      it "returns nil for unknown code" do
        expect(dn.of("xyz")).to be_nil
      end
    end

    context "with type: :region" do
      let(:dn) { ICU4X::DisplayNames.new(ICU4X::Locale.parse("ja"), provider:, type: :region) }

      it "returns display name for known region code 'US'" do
        expect(dn.of("US")).to eq("アメリカ合衆国")
      end

      it "returns display name for known region code 'JP'" do
        expect(dn.of("JP")).to eq("日本")
      end

      it "returns display name for known region code 'GB'" do
        expect(dn.of("GB")).to eq("イギリス")
      end
    end

    context "with type: :script" do
      let(:dn) { ICU4X::DisplayNames.new(ICU4X::Locale.parse("ja"), provider:, type: :script) }

      it "returns display name for known script code 'Latn'" do
        expect(dn.of("Latn")).to eq("ラテン文字")
      end

      it "returns display name for known script code 'Hant'" do
        expect(dn.of("Hant")).to eq("繁体字")
      end

      it "returns display name for known script code 'Cyrl'" do
        expect(dn.of("Cyrl")).to eq("キリル文字")
      end
    end

    context "with type: :locale" do
      let(:dn) { ICU4X::DisplayNames.new(ICU4X::Locale.parse("ja"), provider:, type: :locale) }

      it "returns display name for full locale string 'en-US'" do
        expect(dn.of("en-US")).to eq("アメリカ英語")
      end

      it "returns display name for locale with script 'zh-Hant'" do
        expect(dn.of("zh-Hant")).to eq("標準中国語 (繁体字)")
      end

      it "returns display name for locale 'pt-BR'" do
        expect(dn.of("pt-BR")).to eq("ポルトガル語 (ブラジル)")
      end
    end

    context "with English locale" do
      let(:dn) { ICU4X::DisplayNames.new(ICU4X::Locale.parse("en"), provider:, type: :language) }

      it "returns English display name for 'ja'" do
        expect(dn.of("ja")).to eq("Japanese")
      end

      it "returns English display name for 'en'" do
        expect(dn.of("en")).to eq("English")
      end
    end
  end

  describe "#resolved_options" do
    let(:provider) { ICU4X::DataProvider.from_blob(valid_blob_path) }

    it "returns hash with locale, type, style, fallback (defaults)" do
      dn = ICU4X::DisplayNames.new(ICU4X::Locale.parse("ja"), provider:, type: :language)

      expect(dn.resolved_options).to eq({
        locale: "ja",
        type: :language,
        style: :long,
        fallback: :code
      })
    end

    it "returns hash with custom options" do
      dn = ICU4X::DisplayNames.new(
        ICU4X::Locale.parse("en"),
        provider:,
        type: :region,
        style: :short,
        fallback: :none
      )

      expect(dn.resolved_options).to eq({
        locale: "en",
        type: :region,
        style: :short,
        fallback: :none
      })
    end
  end
end
