# frozen_string_literal: true

require "pathname"
require "tmpdir"

RSpec.describe ICU4X::DataGenerator do
  describe ".export" do
    let(:output_dir) { Pathname.new(Dir.mktmpdir) }
    let(:output_path) { output_dir / "test-data.postcard" }

    before do
      allow(Kernel).to receive(:warn)
    end

    after do
      FileUtils.rm_rf(output_dir)
    end

    context "with valid arguments" do
      it "creates a blob file", :slow do
        ICU4X::DataGenerator.export(
          locales: %w[en],
          markers: :all,
          format: :blob,
          output: output_path
        )

        expect(output_path).to exist
        expect(output_path.size).to be > 0
      end

      it "warns when 'und' locale is not included", :slow do
        ICU4X::DataGenerator.export(
          locales: %w[en],
          markers: %w[PluralsCardinalV1],
          format: :blob,
          output: output_path
        )

        expect(Kernel).to have_received(:warn).with(/'und' locale not included/)
      end

      it "does not warn when 'und' locale is included", :slow do
        ICU4X::DataGenerator.export(
          locales: %w[en und],
          markers: %w[PluralsCardinalV1],
          format: :blob,
          output: output_path
        )

        expect(Kernel).not_to have_received(:warn)
      end

      it "creates a blob that can be loaded by DataProvider", :slow do
        ICU4X::DataGenerator.export(
          locales: %w[en],
          markers: :all,
          format: :blob,
          output: output_path
        )

        provider = ICU4X::DataProvider.from_blob(output_path)
        expect(provider).to be_a(ICU4X::DataProvider)
      end

      it "creates a blob with specific markers", :slow do
        # Use plural markers which are relatively small
        ICU4X::DataGenerator.export(
          locales: %w[en],
          markers: %w[PluralsCardinalV1 PluralsOrdinalV1],
          format: :blob,
          output: output_path
        )

        expect(output_path).to exist
        expect(output_path.size).to be > 0
      end
    end

    context "with available_markers" do
      it "returns an array of marker names" do
        markers = ICU4X::DataGenerator.available_markers
        expect(markers).to be_an(Array)
        expect(markers).to include("PluralsCardinalV1")
        expect(markers).to include("PluralsOrdinalV1")
        expect(markers).to include("DecimalSymbolsV1")
      end

      it "returns sorted marker names" do
        markers = ICU4X::DataGenerator.available_markers
        expect(markers).to eq(markers.sort)
      end
    end

    context "with missing arguments" do
      it "raises ArgumentError when locales is missing" do
        expect {
          ICU4X::DataGenerator.export(
            markers: :all,
            format: :blob,
            output: output_path
          )
        }.to raise_error(ArgumentError, /missing required keyword argument: locales/)
      end

      it "raises ArgumentError when markers is missing" do
        expect {
          ICU4X::DataGenerator.export(
            locales: %w[en],
            format: :blob,
            output: output_path
          )
        }.to raise_error(ArgumentError, /missing required keyword argument: markers/)
      end

      it "raises ArgumentError when format is missing" do
        expect {
          ICU4X::DataGenerator.export(
            locales: %w[en],
            markers: :all,
            output: output_path
          )
        }.to raise_error(ArgumentError, /missing required keyword argument: format/)
      end

      it "raises ArgumentError when output is missing" do
        expect {
          ICU4X::DataGenerator.export(
            locales: %w[en],
            markers: :all,
            format: :blob
          )
        }.to raise_error(ArgumentError, /missing required keyword argument: output/)
      end
    end

    context "with invalid arguments" do
      it "raises TypeError when output is not a Pathname" do
        expect {
          ICU4X::DataGenerator.export(
            locales: %w[en],
            markers: :all,
            format: :blob,
            output: output_path.to_s
          )
        }.to raise_error(TypeError, /output must be a Pathname/)
      end

      it "raises ArgumentError for unsupported markers symbol" do
        expect {
          ICU4X::DataGenerator.export(
            locales: %w[en],
            markers: :datetime,
            format: :blob,
            output: output_path
          )
        }.to raise_error(ArgumentError, /markers must be :all or an Array of marker name strings/)
      end

      it "raises ArgumentError for unknown marker name" do
        expect {
          ICU4X::DataGenerator.export(
            locales: %w[en],
            markers: ["UnknownMarkerV1"],
            format: :blob,
            output: output_path
          )
        }.to raise_error(ArgumentError, /unknown marker: 'UnknownMarkerV1'/)
      end

      it "raises ArgumentError for unsupported format" do
        expect {
          ICU4X::DataGenerator.export(
            locales: %w[en],
            markers: :all,
            format: :fs,
            output: output_path
          )
        }.to raise_error(ArgumentError, /only :blob format is currently supported/)
      end

      it "raises ArgumentError for invalid locale" do
        expect {
          ICU4X::DataGenerator.export(
            locales: ["!!!invalid"],
            markers: :all,
            format: :blob,
            output: output_path
          )
        }.to raise_error(ArgumentError, /Invalid locale/)
      end
    end
  end
end
