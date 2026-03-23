require "./spec_helper"

describe CrystalIBAN::LCG do
  describe "#next_number" do
    it "produces the correct first value from the default seed (1)" do
      lcg = CrystalIBAN::LCG.new(1_i64)
      # (12_368_472 * 1 + 10_597_025) % 16_777_213 = 22_965_497 % 16_777_213 = 6_188_284
      lcg.next_number.should eq(6_188_284_i64)
    end

    it "advances state on each call" do
      lcg = CrystalIBAN::LCG.new(1_i64)
      first = lcg.next_number
      second = lcg.next_number
      first.should_not eq(second)
    end

    it "produces deterministic output from the same seed" do
      lcg1 = CrystalIBAN::LCG.new(42_i64)
      lcg2 = CrystalIBAN::LCG.new(42_i64)
      10.times { lcg1.next_number.should eq(lcg2.next_number) }
    end

    it "always returns a value within [0, MODULO)" do
      lcg = CrystalIBAN::LCG.new
      1000.times do
        n = lcg.next_number
        n.should be >= 0_i64
        n.should be < CrystalIBAN::LCG::MODULO
      end
    end
  end

  describe ".step (pure class method)" do
    it "returns the same result as a single next_number call" do
      seed = 1_i64
      CrystalIBAN::LCG.step(seed).should eq(CrystalIBAN::LCG.new(seed).next_number)
    end

    it "is consistent with successive instance calls" do
      seed = 99_i64
      v1 = CrystalIBAN::LCG.step(seed)
      v2 = CrystalIBAN::LCG.step(v1)

      lcg = CrystalIBAN::LCG.new(seed)
      lcg.next_number.should eq(v1)
      lcg.next_number.should eq(v2)
    end
  end
end
