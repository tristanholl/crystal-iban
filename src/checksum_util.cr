require "big"

module CrystalIBAN
  module ChecksumUtil
    # Replaces each uppercase letter with its two-digit numeric code (A=10, Z=35).
    # Single O(n) pass using String::Builder.
    def self.letters_to_digits(s : String) : String
      String.build do |sb|
        s.each_char do |ch|
          if ch >= 'A' && ch <= 'Z'
            sb << (ch.ord - 55) # 'A'.ord=65, 65-55=10 ✓
          else
            sb << ch
          end
        end
      end
    end

    # Calculates the ISO 13616 MOD-97 checksum for IBAN construction.
    def self.calculate_checksum(country_code : String, bank_code : String, account_number : String) : String
      raw = "#{bank_code}#{account_number}#{country_code}00"
      numeric = letters_to_digits(raw)
      checksum = 98 - (numeric.to_big_i % 97)
      checksum.to_s.rjust(2, '0')
    end
  end
end
