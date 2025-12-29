# frozen_string_literal: true

require "pathname"

RSpec.describe ICU4X::DataProvider do
  let(:fixtures_path) { Pathname.new(__dir__).parent / "fixtures" }
  let(:valid_blob_path) { fixtures_path / "test.blob" }
  let(:nonexistent_path) { fixtures_path / "nonexistent.blob" }

  describe ".from_blob" do
    context "with a valid blob file" do
      it "creates a DataProvider instance" do
        provider = ICU4X::DataProvider.from_blob(valid_blob_path)

        expect(provider).to be_a(ICU4X::DataProvider)
      end
    end

    context "with a nonexistent file" do
      it "raises IOError" do
        expect { ICU4X::DataProvider.from_blob(nonexistent_path) }
          .to raise_error(IOError, /Failed to read blob file/)
      end
    end

    context "with invalid argument type" do
      it "raises TypeError for String" do
        expect { ICU4X::DataProvider.from_blob(valid_blob_path.to_s) }
          .to raise_error(TypeError, /expected Pathname, got String/)
      end

      it "raises TypeError for nil" do
        expect { ICU4X::DataProvider.from_blob(nil) }
          .to raise_error(TypeError, /expected Pathname, got NilClass/)
      end
    end

    context "with invalid blob data" do
      it "raises DataError" do
        invalid_blob_path = fixtures_path / "invalid.blob"
        invalid_blob_path.write("not a valid blob")

        begin
          expect { ICU4X::DataProvider.from_blob(invalid_blob_path) }
            .to raise_error(ICU4X::DataError, /Failed to create data provider/)
        ensure
          invalid_blob_path.delete
        end
      end
    end
  end
end
