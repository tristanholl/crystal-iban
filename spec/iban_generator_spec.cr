require "./spec_helper"
require "big"

describe CrystalIBAN::IBANGenerator do
  # No-arg constructor is the standard shard API — uses bundled JSON embedded
  # at compile time; no file path needed.
  generator = CrystalIBAN::IBANGenerator.new

  describe "#generate" do
    it "generates a 21-character LI IBAN" do
      # LI format: CCXX BBBBB AAAAAAAAAAAA → 2+2+5+12 = 21 chars (no spaces)
      iban = generator.generate(
        country_code: "LI",
        bank_code: "08810",
        account_number: 6_188_284_i64
      )
      iban.size.should eq(21)
    end

    it "starts with the correct country code" do
      iban = generator.generate(
        country_code: "LI",
        bank_code: "08810",
        account_number: 6_188_284_i64
      )
      iban[0, 2].should eq("LI")
    end

    it "places a 2-digit checksum at positions 2-3" do
      iban = generator.generate(
        country_code: "LI",
        bank_code: "08810",
        account_number: 6_188_284_i64
      )
      iban[2, 2].should match(/\A\d{2}\z/)
    end

    it "embeds the bank code at the correct position" do
      iban = generator.generate(
        country_code: "LI",
        bank_code: "08810",
        account_number: 6_188_284_i64
      )
      iban[4, 5].should eq("08810")
    end

    it "zero-pads short account numbers to the country-required length" do
      iban = generator.generate(
        country_code: "LI",
        bank_code: "08810",
        account_number: 42_i64
      )
      # Account portion starts at offset 9 (2+2+5) and is 12 digits for LI
      iban[9, 12].should eq("000000000042")
    end

    it "raises ArgumentError for unsupported country codes" do
      expect_raises(ArgumentError, /not supported/) do
        generator.generate(
          country_code: "XX",
          bank_code: "00000",
          account_number: 1_i64
        )
      end
    end

    it "generates a 22-character DE IBAN" do
      # DE format: CCXX BBBBBBBB AAAAAAAAAA → 2+2+8+10 = 22 chars
      iban = generator.generate(
        country_code: "DE",
        bank_code: "37040044",
        account_number: 532_013_000_i64
      )
      iban.size.should eq(22)
      iban[0, 2].should eq("DE")
    end
  end

  describe "custom json: constructor" do
    it "accepts an inline JSON string in lieu of the bundled data" do
      custom_json = %([{"country":"Testland","country_code":"TS","iban_format":"CCXX BBBB AAAA AAAA"}])
      gen = CrystalIBAN::IBANGenerator.new(json: custom_json)
      iban = gen.generate(country_code: "TS", bank_code: "1234", account_number: 56_i64)
      # TS + 2-digit checksum + 1234 + 00000056 = 2+2+4+8 = 16 chars
      iban.size.should eq(16)
      iban[0, 2].should eq("TS")
    end
  end

  describe "#validate!" do
    it "returns the normalized IBAN for a valid input" do
      iban = generator.generate(
        country_code: "LI",
        bank_code: "08810",
        account_number: 6_188_284_i64
      )
      generator.validate!(iban).should eq(iban)
    end

    it "strips spaces and uppercases before validating" do
      # Pretty-printed IBAN with spaces and lowercase — still valid
      # LI0608810000006188284 in groups of 4: LI06 0881 0000 0061 8828 4
      generator.validate!("li06 0881 0000 0061 8828 4").should eq("LI0608810000006188284")
    end

    it "raises on unknown country code" do
      expect_raises(ArgumentError, /not supported/) do
        generator.validate!("XX050881006188284")
      end
    end

    it "raises when length is wrong for the country" do
      expect_raises(ArgumentError, /length.*invalid/) do
        generator.validate!("LI0608810000006188") # 18 chars — too short for LI (expected 21)
      end
    end

    it "raises when checksum is wrong" do
      expect_raises(ArgumentError, /checksum invalid/) do
        # Same structure as a valid LI IBAN but with "00" instead of the correct "06"
        generator.validate!("LI0008810000006188284")
      end
    end

    it "validates every IBAN produced by generate (round-trip)" do
      lcg = CrystalIBAN::LCG.new
      ["LI", "DE", "CH"].each do |cc|
        account = lcg.next_number
        bank_codes = {"LI" => "08810", "DE" => "37040044", "CH" => "00762"}
        iban = generator.generate(
          country_code: cc,
          bank_code: bank_codes[cc],
          account_number: account
        )
        generator.validate!(iban).should eq(iban)
      end
    end
  end

  describe "#valid?" do
    it "returns true for a valid IBAN" do
      iban = generator.generate(
        country_code: "LI",
        bank_code: "08810",
        account_number: 6_188_284_i64
      )
      generator.valid?(iban).should be_true
    end

    it "returns true for a spaced/lowercased valid IBAN" do
      generator.valid?("li06 0881 0000 0061 8828 4").should be_true
    end

    it "returns false for an unknown country" do
      generator.valid?("XX0608810000006188284").should be_false
    end

    it "returns false for a bad checksum" do
      # Valid length for LI (21) but checksum "99" is wrong
      generator.valid?("LI9908810000006188284").should be_false
    end

    it "returns false for a string that is too short" do
      generator.valid?("LI").should be_false
    end
  end

  describe "MOD-97 checksum validity" do
    it "produces IBANs that pass the ISO 13616 round-trip check" do
      iban = generator.generate(
        country_code: "LI",
        bank_code: "08810",
        account_number: 6_188_284_i64
      )

      # ISO 13616 verification:
      # 1. Move first 4 characters to the end.
      # 2. Replace each letter with its numeric code (A=10 ... Z=35).
      # 3. Compute the integer value mod 97 — must equal 1.
      rearranged = iban[4..] + iban[0, 4]
      numeric = String.build do |sb|
        rearranged.each_char do |ch|
          ch >= 'A' && ch <= 'Z' ? sb << (ch.ord - 55) : sb << ch
        end
      end
      (numeric.to_big_i % 97).should eq(1)
    end

    it "passes the MOD-97 check for multiple generated LI IBANs" do
      lcg = CrystalIBAN::LCG.new
      5.times do
        account = lcg.next_number
        iban = generator.generate(
          country_code: "LI",
          bank_code: "08810",
          account_number: account
        )
        rearranged = iban[4..] + iban[0, 4]
        numeric = String.build do |sb|
          rearranged.each_char do |ch|
            ch >= 'A' && ch <= 'Z' ? sb << (ch.ord - 55) : sb << ch
          end
        end
        (numeric.to_big_i % 97).should eq(1), "IBAN #{iban} failed MOD-97 check"
      end
    end
  end
end
