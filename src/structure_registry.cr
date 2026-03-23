require "json"
require "./models/iban_structure"

module CrystalIBAN
  # Parses and holds the country IBAN pattern data.
  # Can be shared between a Generator and Validator to avoid parsing JSON twice.
  class StructureRegistry
    BUNDLED_JSON = {{ read_file("#{__DIR__}/../data/iban_structure.json") }}

    getter structures : Hash(String, IbanPattern)

    # Loads the bundled 49-country IBAN structures compiled into the binary.
    def initialize
      initialize(json: BUNDLED_JSON)
    end

    # Loads IBAN structures from a custom JSON string in the same format as
    # iban_structure.json. Use this to extend or override the default country set.
    def initialize(*, json : String)
      @structures = Hash(String, IbanPattern).new

      entries = Array(IbanEntry).from_json(json)
      entries.each do |entry|
        fmt = entry.iban_format

        bank_code_len = fmt.count('B')
        account_num_len = fmt.count('A')
        country_code_len = fmt.count('C')
        checksum_len = fmt.count('X')

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
  end
end
