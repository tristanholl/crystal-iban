require "./spec_helper"

describe CrystalIBAN::Generator do
  generator = CrystalIBAN::Generator.new

  describe "#generate" do
    it "generates a 21-character LI IBAN" do
      iban = generator.generate(country_code: "LI", bank_code: "08810", account_number: 6_188_284_i64)
      iban.size.should eq(21)
    end

    it "starts with the correct country code" do
      iban = generator.generate(country_code: "LI", bank_code: "08810", account_number: 6_188_284_i64)
      iban[0, 2].should eq("LI")
    end

    it "places a 2-digit checksum at positions 2-3" do
      iban = generator.generate(country_code: "LI", bank_code: "08810", account_number: 6_188_284_i64)
      iban[2, 2].should match(/\A\d{2}\z/)
    end

    it "embeds the bank code at the correct position" do
      iban = generator.generate(country_code: "LI", bank_code: "08810", account_number: 6_188_284_i64)
      iban[4, 5].should eq("08810")
    end

    it "zero-pads short account numbers to the country-required length" do
      iban = generator.generate(country_code: "LI", bank_code: "08810", account_number: 42_i64)
      iban[9, 12].should eq("000000000042")
    end

    it "raises ArgumentError for unsupported country codes" do
      expect_raises(ArgumentError, /not supported/) do
        generator.generate(country_code: "XX", bank_code: "00000", account_number: 1_i64)
      end
    end

    it "generates a 22-character DE IBAN" do
      iban = generator.generate(country_code: "DE", bank_code: "37040044", account_number: 532_013_000_i64)
      iban.size.should eq(22)
      iban[0, 2].should eq("DE")
    end
  end

  describe ".generate" do
    it "generates a valid IBAN without instantiation" do
      iban = CrystalIBAN::Generator.generate(country_code: "LI", bank_code: "08810", account_number: 6_188_284_i64)
      iban.should eq("LI0608810000006188284")
    end

    it "raises ArgumentError for unsupported country codes without instantiation" do
      expect_raises(ArgumentError, /not supported/) do
        CrystalIBAN::Generator.generate(country_code: "XX", bank_code: "00000", account_number: 1_i64)
      end
    end
  end

  describe "custom json constructor" do
    it "accepts an inline JSON string in lieu of the bundled data" do
      custom_json = %([{"country":"Testland","country_code":"TS","iban_format":"CCXX BBBB AAAA AAAA"}])
      gen = CrystalIBAN::Generator.new(json: custom_json)
      iban = gen.generate(country_code: "TS", bank_code: "1234", account_number: 56_i64)
      iban.size.should eq(16)
      iban[0, 2].should eq("TS")
    end
  end
end
