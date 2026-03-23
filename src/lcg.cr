module CrystalIBAN
  # Linear Congruential Generator for pseudo-random account number sequences.
  #
  # Algorithm: X(n+1) = (MULTIPLIER * X(n) + INCREMENT) % MODULO
  #
  # Parameters sourced from:
  # https://www.ams.org/journals/mcom/1999-68-225/S0025-5718-99-00996-5/S0025-5718-99-00996-5.pdf
  #
  # These constants can generate up to 16_777_213 unique account numbers before
  # the sequence repeats — enough to cover Liechtenstein's 12-digit account space
  # with room for account type prefixes:
  #
  #   0000xxxxxxxx  Internal accounts
  #   0001xxxxxxxx  Regular accounts
  #   0002xxxxxxxx  Virtual IBANs
  #   0003xxxxxxxx  Lending accounts
  class LCG
    MULTIPLIER = 12_368_472_i64
    INCREMENT  = 10_597_025_i64
    MODULO     = 16_777_213_i64 # 2^24 - 3

    # Current generator state. Seed it with any non-zero value.
    getter state : Int64

    def initialize(@state : Int64 = 1_i64)
    end

    # Advances the generator by one step, updates internal state, and returns
    # the new value. Equivalent to Ruby's generate_next_number(last_number: 1)
    # called repeatedly on the same object.
    def next_number : Int64
      @state = (MULTIPLIER * @state + INCREMENT) % MODULO
    end

    # Pure function variant of the LCG step — useful in tests and one-off
    # calculations without needing a stateful instance.
    def self.step(n : Int64) : Int64
      (MULTIPLIER * n + INCREMENT) % MODULO
    end
  end
end
