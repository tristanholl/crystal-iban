require "./checksum_util"
require "./structure_registry"
require "./validator"

module CrystalIBAN
  # Generates valid IBAN strings for supported countries.
  class Generator
    # Creates a generator pre-loaded with the bundled 49-country IBAN structures.
    # This is the standard constructor for shard consumers.
    #
    # ```
    # gen = CrystalIBAN::Generator.new
    # gen.generate(country_code: "LI", bank_code: "08810", account_number: 6_188_284_i64)
    # # => "LI05088106188284"
    # ```
    def initialize
      @registry = StructureRegistry.new
      @validator = nil.as(Validator?)
    end

    # Creates a generator using a shared StructureRegistry.
    # Use this when you also have a Validator to avoid parsing the JSON twice.
    def initialize(*, registry : StructureRegistry)
      @registry = registry
      @validator = nil.as(Validator?)
    end

    # Creates a generator from a custom JSON string in the same format as
    # iban_structure.json. Use this to extend or override the default country set.
    #
    # ```
    # custom_json = %([{"country":"Testland","country_code":"TS","iban_format":"CCXX BBBB AAAA"}])
    # gen = CrystalIBAN::Generator.new(json: custom_json)
    # ```
    def initialize(*, json : String)
      @registry = StructureRegistry.new(json: json)
      @validator = nil.as(Validator?)
    end

    # Generates a complete IBAN string for the given country and account details.
    # Raises ArgumentError if the country code is not in the loaded structure file.
    def generate(country_code : String, bank_code : String, account_number : Int64) : String
      pattern = @registry.structures[country_code]?
      raise ArgumentError.new("Country #{country_code} not supported") if pattern.nil?

      padded_account = account_number.to_s.rjust(pattern.account_number_length, '0')
      checksum = ChecksumUtil.calculate_checksum(country_code, bank_code, padded_account)
      "#{country_code}#{checksum}#{bank_code}#{padded_account}"
    end

    # Deprecated: use CrystalIBAN::Validator#valid? instead.
    def valid?(iban : String) : Bool
      lazy_validator.valid?(iban)
    end

    # Deprecated: use CrystalIBAN::Validator#validate! instead.
    def validate!(iban : String) : String
      lazy_validator.validate!(iban)
    end

    private def lazy_validator : Validator
      @validator ||= Validator.new(registry: @registry)
      @validator.not_nil!
    end
  end
end
