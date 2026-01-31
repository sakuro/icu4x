# frozen_string_literal: true

RSpec.describe ICU4X::FormattedPart do
  it "inherits from Data" do
    expect(ICU4X::FormattedPart).to be < Data
  end

  it "has type and value members" do
    expect(ICU4X::FormattedPart.members).to eq(%i[type value])
  end

  describe "#inspect" do
    it "returns a human-readable representation" do
      part = ICU4X::FormattedPart[:integer, "123"]

      expect(part.inspect).to eq('#<ICU4X::FormattedPart type=:integer value="123">')
    end
  end
end
