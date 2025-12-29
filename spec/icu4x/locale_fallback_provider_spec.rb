# frozen_string_literal: true

require "pathname"

RSpec.describe ICU4X::LocaleFallbackProvider do
  let(:fixtures_path) { Pathname.new(__dir__).parent / "fixtures" }
  let(:valid_blob_path) { fixtures_path / "test-data.postcard" }

  describe ".new" do
    context "with valid DataProvider" do
      it "creates a LocaleFallbackProvider instance with default priority" do
        provider = ICU4X::DataProvider.from_blob(valid_blob_path)
        fallback_provider = ICU4X::LocaleFallbackProvider.new(provider)

        expect(fallback_provider).to be_a(ICU4X::LocaleFallbackProvider)
      end

      it "creates a LocaleFallbackProvider instance with :language priority" do
        provider = ICU4X::DataProvider.from_blob(valid_blob_path)
        fallback_provider = ICU4X::LocaleFallbackProvider.new(provider, priority: :language)

        expect(fallback_provider).to be_a(ICU4X::LocaleFallbackProvider)
      end

      it "creates a LocaleFallbackProvider instance with :region priority" do
        provider = ICU4X::DataProvider.from_blob(valid_blob_path)
        fallback_provider = ICU4X::LocaleFallbackProvider.new(provider, priority: :region)

        expect(fallback_provider).to be_a(ICU4X::LocaleFallbackProvider)
      end
    end

    context "with invalid priority" do
      it "raises ArgumentError for unknown priority symbol" do
        provider = ICU4X::DataProvider.from_blob(valid_blob_path)

        expect { ICU4X::LocaleFallbackProvider.new(provider, priority: :unknown) }
          .to raise_error(ArgumentError, /priority must be :language or :region/)
      end
    end

    context "with already consumed DataProvider" do
      it "raises ArgumentError" do
        provider = ICU4X::DataProvider.from_blob(valid_blob_path)
        ICU4X::LocaleFallbackProvider.new(provider)

        expect { ICU4X::LocaleFallbackProvider.new(provider) }
          .to raise_error(ArgumentError, /DataProvider has already been consumed/)
      end
    end

    context "with invalid argument type" do
      it "raises TypeError for non-DataProvider" do
        expect { ICU4X::LocaleFallbackProvider.new("not a provider") }
          .to raise_error(TypeError)
      end

      it "raises TypeError for nil" do
        expect { ICU4X::LocaleFallbackProvider.new(nil) }
          .to raise_error(TypeError)
      end
    end
  end
end
