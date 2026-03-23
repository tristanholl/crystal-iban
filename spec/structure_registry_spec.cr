require "./spec_helper"

describe CrystalIBAN::StructureRegistry do
  describe "default constructor" do
    it "loads the bundled 49-country data" do
      registry = CrystalIBAN::StructureRegistry.new
      registry.structures.size.should eq(49)
    end

    it "includes LI, DE, CH structures" do
      registry = CrystalIBAN::StructureRegistry.new
      registry.structures.has_key?("LI").should be_true
      registry.structures.has_key?("DE").should be_true
      registry.structures.has_key?("CH").should be_true
    end
  end

  describe "custom json constructor" do
    it "parses a custom JSON string" do
      custom_json = %([{"country":"Testland","country_code":"TS","iban_format":"CCXX BBBB AAAA AAAA"}])
      registry = CrystalIBAN::StructureRegistry.new(json: custom_json)
      registry.structures.has_key?("TS").should be_true
    end

    it "raises on malformed entries (country_code too long)" do
      bad_json = %([{"country":"Bad","country_code":"TOO","iban_format":"CCXX BBBB AAAA"}])
      expect_raises(Exception) do
        CrystalIBAN::StructureRegistry.new(json: bad_json)
      end
    end
  end
end
