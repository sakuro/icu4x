# frozen_string_literal: true

RSpec.describe ICU4X do
  let(:fixtures_path) { Pathname.new(__dir__) / "fixtures" }
  let(:valid_blob_path) { fixtures_path / "test-data.postcard" }
  let(:nonexistent_path) { fixtures_path / "nonexistent.postcard" }

  describe ".config" do
    around do |example|
      original_env = ENV.fetch("ICU4X_DATA_PATH", nil)
      ENV.delete("ICU4X_DATA_PATH")
      example.run
    ensure
      ENV["ICU4X_DATA_PATH"] = original_env
    end

    it "has a data_path setting that defaults to nil" do
      expect(ICU4X.config.data_path).to be_nil
    end

    it "accepts a Pathname for data_path" do
      ICU4X.configure {|config| config.data_path = valid_blob_path }
      expect(ICU4X.config.data_path).to eq(valid_blob_path)
    end

    it "converts String to Pathname for data_path" do
      ICU4X.configure {|config| config.data_path = valid_blob_path.to_s }
      expect(ICU4X.config.data_path).to eq(valid_blob_path)
    end
  end

  describe ".default_provider" do
    context "when neither config.data_path nor ENV['ICU4X_DATA_PATH'] is set" do
      around do |example|
        original_env = ENV.fetch("ICU4X_DATA_PATH", nil)
        ENV.delete("ICU4X_DATA_PATH")
        example.run
      ensure
        ENV["ICU4X_DATA_PATH"] = original_env
      end

      it "returns nil" do
        expect(ICU4X.default_provider).to be_nil
      end
    end

    context "when config.data_path is set" do
      around do |example|
        original_env = ENV.fetch("ICU4X_DATA_PATH", nil)
        ENV.delete("ICU4X_DATA_PATH")
        example.run
      ensure
        ENV["ICU4X_DATA_PATH"] = original_env
      end

      before { ICU4X.configure {|config| config.data_path = valid_blob_path } }

      it "returns a DataProvider" do
        expect(ICU4X.default_provider).to be_a(ICU4X::DataProvider)
      end
    end

    context "when ENV['ICU4X_DATA_PATH'] is set" do
      around do |example|
        original_env = ENV.fetch("ICU4X_DATA_PATH", nil)
        ENV["ICU4X_DATA_PATH"] = valid_blob_path.to_s
        example.run
      ensure
        ENV["ICU4X_DATA_PATH"] = original_env
      end

      it "returns a DataProvider" do
        expect(ICU4X.default_provider).to be_a(ICU4X::DataProvider)
      end
    end

    context "when both config.data_path and ENV['ICU4X_DATA_PATH'] are set" do
      around do |example|
        original_env = ENV.fetch("ICU4X_DATA_PATH", nil)
        ENV["ICU4X_DATA_PATH"] = nonexistent_path.to_s
        example.run
      ensure
        ENV["ICU4X_DATA_PATH"] = original_env
      end

      before { ICU4X.configure {|config| config.data_path = valid_blob_path } }

      it "prioritizes config.data_path over ENV" do
        # If ENV were used, it would raise an error for nonexistent path
        expect { ICU4X.default_provider }.not_to raise_error
      end
    end
  end

  describe ".reset_default_provider!" do
    around do |example|
      original_env = ENV.fetch("ICU4X_DATA_PATH", nil)
      ENV.delete("ICU4X_DATA_PATH")
      example.run
    ensure
      ENV["ICU4X_DATA_PATH"] = original_env
    end

    before { ICU4X.configure {|config| config.data_path = valid_blob_path } }

    it "clears the cached default provider" do
      ICU4X.default_provider
      ICU4X.reset_default_provider!
      ICU4X.reset_config
      expect(ICU4X.default_provider).to be_nil
    end
  end
end
