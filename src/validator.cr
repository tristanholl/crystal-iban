require "./checksum_util"
require "./structure_registry"

module CrystalIBAN
  # Validates IBAN strings against the ISO 13616 standard.
  class Validator
    # Creates a validator pre-loaded with the bundled 49-country IBAN structures.
    def initialize
      @registry = StructureRegistry.new
    end

    # Creates a validator using a shared StructureRegistry.
    # Use this when you also have a Generator to avoid parsing the JSON twice.
    #
    # ```
    # registry = CrystalIBAN::StructureRegistry.new
    # gen = CrystalIBAN::Generator.new(registry: registry)
    # val = CrystalIBAN::Validator.new(registry: registry)
    # ```
    def initialize(*, registry : StructureRegistry)
      @registry = registry
    end

    @@default : Validator? = nil

    # Returns true if *iban* is valid using the bundled default registry.
    #
    # ```
    # CrystalIBAN::Validator.valid?("LI05 0881 0061 8828 4") # => true
    # ```
    def self.valid?(iban : String) : Bool
      (@@default ||= new).valid?(iban)
    end

    # Returns the normalized IBAN or raises ArgumentError, using the bundled default registry.
    #
    # ```
    # CrystalIBAN::Validator.validate!("LI05 0881 0061 8828 4") # => "LI050881006188284"
    # ```
    def self.validate!(iban : String) : String
      (@@default ||= new).validate!(iban)
    end

    # Returns true if *iban* is structurally valid for its country and passes
    # the ISO 13616 MOD-97 checksum. Leading/trailing whitespace and internal
    # spaces are stripped; the string is uppercased before checking.
    #
    # ```
    # val = CrystalIBAN::Validator.new
    # val.valid?("LI05 0881 0061 8828 4") # => true
    # val.valid?("LI00 0000 0000 0000 0") # => false  (bad checksum)
    # val.valid?("XX123")                 # => false  (unknown country)
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
    # val = CrystalIBAN::Validator.new
    # val.validate!("LI05 0881 0061 8828 4") # => "LI050881006188284"
    # val.validate!("LI00 0000 0000 0000 0") # raises ArgumentError
    # ```
    def validate!(iban : String) : String
      normalized = iban.delete(' ').upcase

      raise ArgumentError.new("IBAN too short (got #{normalized.size} chars, minimum 4)") if normalized.size < 4

      country_code = normalized[0, 2]
      pattern = @registry.structures[country_code]?
      raise ArgumentError.new("Country #{country_code} not supported") if pattern.nil?

      expected = 2 + 2 + pattern.bank_code_length + pattern.account_number_length
      if normalized.size != expected
        raise ArgumentError.new(
          "IBAN length #{normalized.size} invalid for #{country_code} (expected #{expected})"
        )
      end

      # ISO 13616: move first 4 chars to the end, replace letters with digits, mod 97 must == 1.
      rearranged = normalized[4..] + normalized[0, 4]
      unless ChecksumUtil.letters_to_digits(rearranged).to_big_i % 97 == 1
        raise ArgumentError.new("IBAN checksum invalid for #{normalized}")
      end

      normalized
    end
  end
end
