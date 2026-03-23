require "json"
require "big"
require "./models/iban_structure"

module CrystalIBAN
  class IBANGenerator
    # The 49-country IBAN structure JSON, embedded at compile time.
    # Using read_file means the data file is baked into the binary — no
    # runtime file path is needed, so the shard works as a dependency
    # without the consumer knowing anything about the internal data layout.
    BUNDLED_JSON = {{ read_file("#{__DIR__}/../data/iban_structure.json") }}

    # Keyed by 2-letter ISO country code → pre-parsed IBAN pattern.
    @structures : Hash(String, IbanPattern)

    # Creates a generator pre-loaded with the bundled 49-country IBAN structures.
    # This is the standard constructor for shard consumers.
    #
    # ```
    # gen = CrystalIBAN::IBANGenerator.new
    # gen.generate(country_code: "LI", bank_code: "08810", account_number: 6_188_284_i64)
    # # => "LI05088106188284"
    # ```
    def initialize
      initialize(json: BUNDLED_JSON)
    end

    # Creates a generator from a custom JSON string in the same format as
    # iban_structure.json. Use this to extend or override the default country set.
    #
    # ```
    # custom_json = %([{"country":"Testland","country_code":"TS","iban_format":"CCXX BBBB AAAA"}])
    # gen = CrystalIBAN::IBANGenerator.new(json: custom_json)
    # ```
    def initialize(*, json : String)
      @structures = Hash(String, IbanPattern).new

      entries = Array(IbanEntry).from_json(json)
      entries.each do |entry|
        fmt = entry.iban_format

        bank_code_len     = fmt.count('B')
        account_num_len   = fmt.count('A')
        country_code_len  = fmt.count('C')
        checksum_len      = fmt.count('X')

        unless entry.country_code.size == 2 &&
               country_code_len == 2 &&
               checksum_len == 2
          raise "Unsupported IBAN pattern for #{entry.country_code}"
        end

        @structures[entry.country_code] = IbanPattern.new(
          country: entry.country,
          country_code: entry.country_code,
          bank_code_length: bank_code_len,
          account_number_length: account_num_len
        )
      end
    end

    # Generates a complete IBAN string for the given country and account details.
    # Raises ArgumentError if the country code is not in the loaded structure file.
    def generate(country_code : String, bank_code : String, account_number : Int64) : String
      pattern = @structures[country_code]?
      raise ArgumentError.new("Country #{country_code} not supported") if pattern.nil?

      padded_account = account_number.to_s.rjust(pattern.account_number_length, '0')
      checksum = calculate_checksum(country_code, bank_code, padded_account)
      "#{country_code}#{checksum}#{bank_code}#{padded_account}"
    end

    # Returns true if *iban* is structurally valid for its country and passes
    # the ISO 13616 MOD-97 checksum. Leading/trailing whitespace and internal
    # spaces are stripped; the string is uppercased before checking.
    #
    # ```
    # gen = CrystalIBAN::IBANGenerator.new
    # gen.valid?("LI05 0881 0061 8828 4")  # => true
    # gen.valid?("LI00 0000 0000 0000 0")  # => false  (bad checksum)
    # gen.valid?("XX123")                  # => false  (unknown country)
    # ```
    def valid?(iban : String) : Bool
      validate!(iban)
      true
    rescue ArgumentError
      false
    end

    # Returns the normalized IBAN (uppercased, spaces removed) if it is valid,
    # or raises ArgumentError with a human-readable explanation of the failure.
    #
    # Checks performed in order:
    #   1. Minimum length (≥ 4 characters after stripping spaces)
    #   2. Country code is supported by the loaded structure data
    #   3. Total length matches the country's expected IBAN length
    #   4. MOD-97 checksum equals 1 (ISO 13616)
    #
    # ```
    # gen = CrystalIBAN::IBANGenerator.new
    # gen.validate!("LI05 0881 0061 8828 4")   # => "LI050881006188284"
    # gen.validate!("LI00 0000 0000 0000 0")   # raises ArgumentError
    # ```
    def validate!(iban : String) : String
      normalized = iban.delete(' ').upcase

      raise ArgumentError.new("IBAN too short (got #{normalized.size} chars, minimum 4)") if normalized.size < 4

      country_code = normalized[0, 2]
      pattern = @structures[country_code]?
      raise ArgumentError.new("Country #{country_code} not supported") if pattern.nil?

      expected = 2 + 2 + pattern.bank_code_length + pattern.account_number_length
      if normalized.size != expected
        raise ArgumentError.new(
          "IBAN length #{normalized.size} invalid for #{country_code} (expected #{expected})"
        )
      end

      # ISO 13616: move first 4 chars to the end, replace letters with digits, mod 97 must == 1.
      rearranged = normalized[4..] + normalized[0, 4]
      unless letters_to_digits(rearranged).to_big_i % 97 == 1
        raise ArgumentError.new("IBAN checksum invalid for #{normalized}")
      end

      normalized
    end

    private def calculate_checksum(country_code : String, bank_code : String, account_number : String) : String
      # Build the reordered string: bank_code + account_number + country_code + "00"
      # then convert letters to their numeric equivalents (A=10 ... Z=35).
      raw = "#{bank_code}#{account_number}#{country_code}00"
      numeric = letters_to_digits(raw)

      # MOD-97 checksum per ISO 13616.
      # Ruby silently promotes to Bignum; Crystal requires explicit BigInt because
      # the numeric string can exceed 30 digits — well beyond Int64's range.
      checksum = 98 - (numeric.to_big_i % 97)
      checksum.to_s.rjust(2, '0')
    end

    # Replaces each uppercase letter with its two-digit numeric code (A=10, Z=35).
    # Single O(n) pass using String::Builder — replaces Ruby's 26 full-string gsub calls.
    private def letters_to_digits(s : String) : String
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
  end
end
