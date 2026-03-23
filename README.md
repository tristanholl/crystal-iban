# crystal-iban

A Crystal shard for generating and validating [IBAN](https://en.wikipedia.org/wiki/International_Bank_Account_Number) (International Bank Account Number) strings. Uses the ISO 13616 MOD-97 checksum algorithm and supports 52 countries. IBAN structure data is embedded at compile time — no runtime file dependency.

## Features

- Generate structurally valid IBANs with a correct MOD-97 checksum
- Validate any IBAN string with detailed error messages
- Pseudo-random account number generation via a Linear Congruential Generator (LCG)
- 52 countries supported out of the box
- Extensible: supply your own JSON to add or override country definitions
- Zero runtime file I/O — structure data is baked into the binary at compile time

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  crystal_iban:
    github: tristanholl/crystal-iban
```

Then run:

```
shards install
```

## Quick Start

```crystal
require "crystal_iban"

gen = CrystalIBAN::Generator.new
val = CrystalIBAN::Validator.new

# Generate a valid IBAN
iban = gen.generate(country_code: "DE", bank_code: "37040044", account_number: 532_013_000_i64)
# => "DE89370400440532013000"

# Validate a string
val.valid?("DE89 3704 0044 0532 0130 00")  # => true  (spaces and case are ignored)
val.valid?("DE00 3704 0044 0532 0130 00")  # => false (bad checksum)

# Validate with error detail
val.validate!("DE89 3704 0044 0532 0130 00")  # => "DE89370400440532013000"
val.validate!("DE00 3704 0044 0532 0130 00")  # raises ArgumentError: "IBAN checksum invalid for DE00370400440532013000"
```

## API Reference

### `CrystalIBAN::Generator`

Generates valid IBAN strings. Responsible solely for construction.

#### Constructors

```crystal
# Standard: loads the bundled 52-country data compiled into the binary.
gen = CrystalIBAN::Generator.new

# Custom JSON: extend or override the default country set.
custom_json = %([{"country":"Testland","country_code":"TS","iban_format":"CCXX BBBB AAAA AAAA"}])
gen = CrystalIBAN::Generator.new(json: custom_json)

# Shared registry: avoids parsing JSON twice when also using a Validator.
registry = CrystalIBAN::StructureRegistry.new
gen = CrystalIBAN::Generator.new(registry: registry)
```

#### Methods

```crystal
gen.generate(country_code : String, bank_code : String, account_number : Int64) : String
```

Generates a complete, valid IBAN string.

- `country_code` — ISO 3166-1 alpha-2 code (e.g. `"DE"`, `"LI"`, `"CH"`)
- `bank_code` — Bank identifier string; must match the length defined for the country
- `account_number` — Account number as `Int64`; automatically zero-padded to the country's required length

Raises `ArgumentError` if `country_code` is not in the loaded structure data.

```crystal
gen.generate(country_code: "LI", bank_code: "08810", account_number: 6_188_284_i64)
# => "LI05088106188284"

gen.generate(country_code: "CH", bank_code: "00762", account_number: 11_863_i64)
# => "CH5600762000000011863"
```

---

### `CrystalIBAN::Validator`

Validates IBAN strings against the ISO 13616 standard. Responsible solely for validation.

#### Constructors

```crystal
# Standard: loads the bundled 52-country data.
val = CrystalIBAN::Validator.new

# Shared registry: avoids parsing JSON twice when also using a Generator.
registry = CrystalIBAN::StructureRegistry.new
val = CrystalIBAN::Validator.new(registry: registry)
```

#### Methods

##### `valid?(iban : String) : Bool`

Returns `true` if the IBAN is valid, `false` otherwise. Never raises.

Before checking, the input is stripped of all spaces and uppercased — human-formatted IBANs like `"DE89 3704 0044 0532 0130 00"` are accepted.

Checks performed (in order):
1. Length is at least 4 characters
2. Country code (first 2 characters) is supported
3. Total length matches the country's expected IBAN length
4. MOD-97 checksum equals 1 (ISO 13616)

```crystal
val.valid?("LI05 0881 0061 8828 4")   # => true
val.valid?("li05 0881 0061 8828 4")   # => true  (case insensitive)
val.valid?("LI00 0000 0000 0000 0")   # => false (bad checksum)
val.valid?("XX050881006188284")        # => false (unknown country)
val.valid?("LI")                      # => false (too short)
```

##### `validate!(iban : String) : String`

Returns the normalized IBAN (uppercased, spaces removed) if valid. Raises `ArgumentError` with a descriptive message on the first failing check.

```crystal
val.validate!("LI05 0881 0061 8828 4")
# => "LI050881006188284"

val.validate!("LI0008810000006188284")
# raises ArgumentError: "IBAN checksum invalid for LI0008810000006188284"

val.validate!("LI0608810000006188")
# raises ArgumentError: "IBAN length 18 invalid for LI (expected 21)"

val.validate!("XX050881006188284")
# raises ArgumentError: "Country XX not supported"
```

---

### `CrystalIBAN::StructureRegistry`

Parses and holds the country IBAN pattern data. Normally used indirectly through `Generator` and `Validator`, but can be instantiated directly to share parsed data between both:

```crystal
registry = CrystalIBAN::StructureRegistry.new

gen = CrystalIBAN::Generator.new(registry: registry)
val = CrystalIBAN::Validator.new(registry: registry)

# Both now share one parsed Hash — the JSON is only parsed once.
iban = gen.generate(country_code: "DE", bank_code: "37040044", account_number: 532_013_000_i64)
val.valid?(iban)  # => true
```

The registry exposes a read-only `structures` getter:

```crystal
registry.structures         # => Hash(String, IbanPattern)
registry.structures["DE"]   # => IbanPattern for Germany
registry.structures["DE"].bank_code_length          # => 8
registry.structures["DE"].account_number_length     # => 10
```

---

### `CrystalIBAN::LCG`

A [Linear Congruential Generator](https://en.wikipedia.org/wiki/Linear_congruential_generator) for producing pseudo-random account numbers. Useful for test data generation or seeded, reproducible sequences.

```crystal
lcg = CrystalIBAN::LCG.new         # default seed: 1
lcg = CrystalIBAN::LCG.new(42_i64) # custom seed
```

#### Methods

```crystal
lcg.next_number : Int64   # stateful: advances internal state and returns the next value
LCG.step(n : Int64) : Int64  # pure function: returns the next value from n without creating an instance
```

```crystal
lcg = CrystalIBAN::LCG.new(1_i64)
lcg.next_number  # => 6_188_284
lcg.next_number  # => advances again; deterministic from the same seed

CrystalIBAN::LCG.step(1_i64)  # => 6_188_284 (same result, no state)
```

The generator produces up to **16,777,213 unique values** before the sequence repeats (period = MODULO = 2²⁴ − 3). Constants are sourced from AMS research paper [S0025-5718-99-00996-5](https://www.ams.org/journals/mcom/1999-68-225/S0025-5718-99-00996-5/S0025-5718-99-00996-5.pdf).

Combining `LCG` with `Generator`:

```crystal
lcg = CrystalIBAN::LCG.new
gen = CrystalIBAN::Generator.new

10.times do
  account = lcg.next_number
  puts gen.generate(country_code: "LI", bank_code: "08810", account_number: account)
end
```

---

### Deprecated: `CrystalIBAN::IBANGenerator`

`IBANGenerator` is a backward-compatibility type alias for `Generator`:

```crystal
alias IBANGenerator = Generator
```

All existing call sites continue to compile unchanged. `IBANGenerator` also retains `valid?` and `validate!` as deprecated delegation methods that forward to an internally managed `Validator`.

Prefer using `Generator` and `Validator` directly in new code.

---

## IBAN Structure and Format

An IBAN is composed of four parts concatenated without spaces:

```
{CC}{XX}{BBBBB...}{AAAAAA...}
 ^    ^    ^          ^
 |    |    |          Account number (zero-padded to country length)
 |    |    Bank code (length varies by country)
 |    2-digit MOD-97 checksum
 2-letter ISO country code
```

The `iban_format` field in the bundled JSON encodes this layout using placeholder characters:

| Character | Meaning |
|-----------|---------|
| `C` | Country code position (always 2) |
| `X` | Checksum position (always 2) |
| `B` | Bank code digit (count = bank code length) |
| `A` | Account number digit (count = account number length) |

Example for Germany (`DE`):

```
Format:  CCXX BBBB BBBB AAAA AAAA AA
Decoded: 2-char country + 2-char checksum + 8-char bank code + 10-char account
Total:   22 characters
```

Spaces in the format string are cosmetic — the generated IBAN contains no spaces.

---

## MOD-97 Checksum Algorithm (ISO 13616)

The checksum is calculated as follows:

**Generation:**
1. Construct the string: `{bank_code}{account_number}{country_code}00`
2. Replace each letter with its numeric code: `A=10`, `B=11`, ..., `Z=35`
3. Compute `98 - (numeric_value mod 97)`, zero-padded to 2 digits

**Validation:**
1. Normalize the IBAN (uppercase, remove spaces)
2. Rearrange: move the first 4 characters to the end
3. Replace each letter with its numeric code
4. Compute `numeric_value mod 97` — must equal `1`

Crystal requires explicit `BigInt` for this calculation because the numeric string can exceed 30 digits, which is well beyond the `Int64` range.

---

## Supported Countries

52 countries are bundled in `data/iban_structure.json` and compiled into the binary:

| Code | Country | IBAN Length |
|------|---------|-------------|
| AL | Albania | 28 |
| AT | Austria | 20 |
| BA | Bosnia and Herzegovina | 20 |
| BE | Belgium | 16 |
| BG | Bulgaria | 22 |
| CH | Switzerland | 21 |
| CY | Cyprus | 28 |
| CZ | Czech Republic | 24 |
| DE | Germany | 22 |
| DK | Denmark | 18 |
| EE | Estonia | 20 |
| ES | Spain | 24 |
| FI | Finland | 18 |
| FO | Faroe Islands | 18 |
| FR | France | 27 |
| GB | United Kingdom | 22 |
| GE | Georgia | 22 |
| GI | Gibraltar | 23 |
| GL | Greenland | 18 |
| GR | Greece | 27 |
| HR | Croatia | 21 |
| HU | Hungary | 28 |
| IE | Ireland | 22 |
| IL | Israel | 23 |
| IS | Iceland | 26 |
| IT | Italy | 27 |
| KW | Kuwait | 30 |
| KZ | Kazakhstan | 20 |
| LB | Lebanon | 28 |
| LI | Liechtenstein | 21 |
| LT | Lithuania | 20 |
| LU | Luxembourg | 20 |
| LV | Latvia | 21 |
| MC | Monaco | 27 |
| ME | Montenegro | 22 |
| MK | Macedonia | 19 |
| MR | Mauritania | 27 |
| MT | Malta | 31 |
| MU | Mauritius | 30 |
| NL | Netherlands | 18 |
| NO | Norway | 15 |
| PL | Poland | 28 |
| PT | Portugal | 25 |
| RO | Romania | 24 |
| RS | Serbia | 22 |
| SA | Saudi Arabia | 24 |
| SE | Sweden | 24 |
| SI | Slovenia | 19 |
| SK | Slovak Republic | 24 |
| SM | San Marino | 27 |
| TN | Tunisia | 24 |
| TR | Turkey | 26 |

---

## Custom Country Definitions

To add countries not in the bundled list, supply a JSON string in the same format as `data/iban_structure.json`:

```crystal
custom_json = %([
  {
    "country": "Testland",
    "country_code": "TS",
    "iban_format": "CCXX BBBB AAAA AAAA"
  }
])

gen = CrystalIBAN::Generator.new(json: custom_json)
gen.generate(country_code: "TS", bank_code: "1234", account_number: 56_i64)
# => "TS741234000000056"  (example — checksum will vary)
```

The format string rules:
- Must contain exactly 2 `C` characters and exactly 2 `X` characters
- `B` characters define the bank code length
- `A` characters define the account number length
- Spaces are cosmetic and ignored during parsing
- `country_code` must be exactly 2 characters

An `ArgumentError` is raised at construction time if any entry fails these constraints.

---

## Project Structure

```
crystal-iban/
├── src/
│   ├── crystal_iban.cr          # Main entry point — requires all modules
│   ├── generator.cr             # CrystalIBAN::Generator
│   ├── validator.cr             # CrystalIBAN::Validator
│   ├── structure_registry.cr    # CrystalIBAN::StructureRegistry
│   ├── checksum_util.cr         # CrystalIBAN::ChecksumUtil (MOD-97 helpers)
│   ├── iban_generator.cr        # Backward-compat alias: IBANGenerator = Generator
│   ├── lcg.cr                   # CrystalIBAN::LCG
│   └── models/
│       └── iban_structure.cr    # IbanEntry (JSON mapping), IbanPattern (domain model)
├── spec/
│   ├── spec_helper.cr
│   ├── generator_spec.cr
│   ├── validator_spec.cr
│   ├── structure_registry_spec.cr
│   ├── iban_generator_spec.cr   # Legacy spec — exercises IBANGenerator alias
│   └── lcg_spec.cr
└── data/
    └── iban_structure.json      # 52-country IBAN format definitions
```

---

## Running Tests

Tests require Docker:

```
make test
```

To open a development console:

```
make console
```

### Test Coverage

| Spec file | What it covers |
|-----------|---------------|
| `generator_spec.cr` | IBAN length per country, country code placement, checksum position, bank code embedding, account number zero-padding, unsupported country error, custom JSON constructor |
| `validator_spec.cr` | Round-trip validation of generated IBANs, space/case normalization, errors for unknown country / wrong length / bad checksum, shared `StructureRegistry` cross-object validation |
| `structure_registry_spec.cr` | Bundled data loads correctly, specific country codes present, custom JSON parsing, malformed entry raises |
| `iban_generator_spec.cr` | Full legacy API surface via the `IBANGenerator` alias — ensures backward compatibility |
| `lcg_spec.cr` | Correct first value from seed 1, state advancement, determinism across instances, range bounds, pure `.step` consistency |

---

## License

MIT — see [LICENSE](LICENSE).
