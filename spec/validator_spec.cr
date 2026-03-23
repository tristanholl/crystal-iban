require "./spec_helper"

describe CrystalIBAN::Validator do
  validator = CrystalIBAN::Validator.new
  generator = CrystalIBAN::Generator.new

  describe "#validate!" do
    it "returns the normalized IBAN for a valid input" do
      iban = generator.generate(country_code: "LI", bank_code: "08810", account_number: 6_188_284_i64)
      validator.validate!(iban).should eq(iban)
    end

    it "strips spaces and uppercases before validating" do
      validator.validate!("li06 0881 0000 0061 8828 4").should eq("LI0608810000006188284")
    end

    it "raises on unknown country code" do
      expect_raises(ArgumentError, /not supported/) do
        validator.validate!("XX050881006188284")
      end
    end

    it "raises when length is wrong for the country" do
      expect_raises(ArgumentError, /length.*invalid/) do
        validator.validate!("LI0608810000006188")
      end
    end

    it "raises when checksum is wrong" do
      expect_raises(ArgumentError, /checksum invalid/) do
        validator.validate!("LI0008810000006188284")
      end
    end

    it "validates every IBAN produced by generate (round-trip)" do
      lcg = CrystalIBAN::LCG.new
      ["LI", "DE", "CH"].each do |cc|
        account = lcg.next_number
        bank_codes = {"LI" => "08810", "DE" => "37040044", "CH" => "00762"}
        iban = generator.generate(country_code: cc, bank_code: bank_codes[cc], account_number: account)
        validator.validate!(iban).should eq(iban)
      end
    end
  end

  describe "#valid?" do
    it "returns true for a valid IBAN" do
      iban = generator.generate(country_code: "LI", bank_code: "08810", account_number: 6_188_284_i64)
      validator.valid?(iban).should be_true
    end

    it "returns true for a spaced/lowercased valid IBAN" do
      validator.valid?("li06 0881 0000 0061 8828 4").should be_true
    end

    it "returns false for an unknown country" do
      validator.valid?("XX0608810000006188284").should be_false
    end

    it "returns false for a bad checksum" do
      validator.valid?("LI9908810000006188284").should be_false
    end

    it "returns false for a string that is too short" do
      validator.valid?("LI").should be_false
    end
  end

  describe "shared StructureRegistry" do
    it "Generator and Validator can share a single registry" do
      registry = CrystalIBAN::StructureRegistry.new
      gen = CrystalIBAN::Generator.new(registry: registry)
      val = CrystalIBAN::Validator.new(registry: registry)
      iban = gen.generate(country_code: "LI", bank_code: "08810", account_number: 6_188_284_i64)
      val.valid?(iban).should be_true
    end
  end
end
