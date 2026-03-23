require "json"

module CrystalIBAN
  # Direct JSON mapping for entries in iban_structure.json.
  # Using JSON::Serializable avoids dynamic Any-based hash access.
  struct IbanEntry
    include JSON::Serializable

    @[JSON::Field(key: "country")]
    getter country : String

    @[JSON::Field(key: "country_code")]
    getter country_code : String

    @[JSON::Field(key: "iban_format")]
    getter iban_format : String
  end

  # Derived from IbanEntry at load time.
  # Stores the pre-counted field lengths so generate() never re-parses the format.
  # Struct (value type) — lives inline in the Hash, no per-entry heap allocation.
  struct IbanPattern
    getter country : String
    getter country_code : String
    getter bank_code_length : Int32
    getter account_number_length : Int32

    def initialize(
      @country : String,
      @country_code : String,
      @bank_code_length : Int32,
      @account_number_length : Int32,
    )
    end
  end
end
