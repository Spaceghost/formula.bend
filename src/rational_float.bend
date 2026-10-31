import Base
import ./decimal.bend as Decimal
import ./binary64.bend as Binary
import ./binary64_decimal.bend as Conversion
import ./bits.bend as Bits

# Ruby 3.3.13 on 64-bit Linux: Integer#fdiv first cancels the gcd,
# then selects a hardware division or the leading-limb bignum algorithm.
# The bignum path rounds its integer quotient before ldexp; that second
# rounding must remain observable at the subnormal boundary.
type Factored is Data:
  FactorResult{digits: List<&2, U32>, remaining: Nat}

def small_division(digits: List<&2, U32>, +divisor: U32, carry: U32, result: List<&2, U32>) -> List<&2, U32>:
  match digits:
    case Nil{}:
      Decimal.normalize_digits(result)
    case digit <> rest:
      +current = U32.add(U32.mul(carry, 10), digit)
      small_division(rest, divisor, U32.mod(current, divisor), U32.div(current, divisor) <> result)

def factor_choice(divisible: Bool, digits: List<&2, U32>, remaining: Nat, next: Unit -> Factored) -> Factored:
  match divisible:
    case True{}:
      next(Unit{})
    case False{}:
      FactorResult{digits, remaining}

def strip_factor(remaining: Nat, +factor: U32, digits: List<&2, U32>) -> Factored:
  match remaining digits:
    case 0n digits:
      FactorResult{digits, 0n}
    case 1n+rest Nil{}:
      FactorResult{Nil{}, Nat.add(1n, rest)}
    case 1n+rest +head <> +tail:
      +rest = rest
      +digits : List<&2, U32> = head <> tail
      factor_choice(U32.is_eq(U32.mod(head, factor), 0), digits, Nat.add(1n, rest), u => strip_factor(rest, factor, small_division(List.reverse(&2, U32, digits), factor, 0, Nil{})))

def finite_kind(kind: Binary.Classification) -> Bool:
  match kind:
    case Binary.Finite{}:
      True{}
    case kind:
      False{}

def fixed_integer(+bits: List<&2, Bool>, +width: Nat, negative: Bool) -> Bool:
  Bool.or(Nat.is_le(width, 62n), Bool.and(negative, Bool.and(Nat.is_eq(width, 63n), Cmp.is_eq(Binary.unsigned_compare(bits, Binary.pad(62n, [True{}]))))))

def scale_finite(+value: Binary.Float, +raised: Nat, +lowered: Nat, negative: Bool) -> Binary.Float:
  Binary.quantize(Binary.pad(Nat.add(Binary.shift(value), Nat.sub(raised, lowered)), Binary.significand(value)), Nat.add(1074n, Nat.sub(lowered, raised)), negative, False{})

def scaled_quotient(parts: List<&2, Bool> & List<&2, Bool>, raised: Nat, lowered: Nat, negative: Bool) -> Binary.Float:
  (quotient, remainder) = parts
  scale_finite(Binary.quantize(quotient, 0n, False{}, False{}), raised, lowered, negative)

def negative_shift(parts: Binary.Removed, negative: Bool) -> List<&2, Bool>:
  match parts:
    case Binary.Cut{+kept, guard, sticky}:
      Bool.pick(List<&2, Bool>, Bool.and(negative, Bool.or(guard, sticky)), Bits.add(kept, [True{}]), kept)

def big_division(+numerator: List<&2, Bool>, +denominator: List<&2, Bool>, +negative: Bool) -> Binary.Float:
  +nwidth = Binary.bit_length(numerator)
  +dwidth = Binary.bit_length(denominator)
  +nup = Nat.sub(128n, nwidth)
  +ndown = Nat.sub(nwidth, 160n)
  +dup = Nat.sub(64n, dwidth)
  +ddown = Nat.sub(dwidth, 64n)
  scaled_quotient(Binary.divide_walk(List.reverse(&2, Bool, negative_shift(Binary.cut(ndown, Binary.pad(nup, numerator), False{}, False{}), negative)), Bits.drop_low(Binary.pad(dup, denominator), ddown), Binary.Step{False{}, Nil{}}, Nil{}), Nat.add(ndown, dup), Nat.add(nup, ddown), negative)

def chosen(direct: Bool, numerator_float: Binary.Float, numerator: List<&2, Bool>, denominator: List<&2, Bool>, negative: Bool) -> Binary.Float:
  match direct:
    case True{}:
      Binary.divide(numerator_float, Binary.quantize(denominator, 0n, False{}, False{}))
    case False{}:
      big_division(numerator, denominator, negative)

def ratio(+numerator: List<&2, Bool>, +denominator: List<&2, Bool>, +negative: Bool) -> Binary.Float:
  +nwidth = Binary.bit_length(numerator)
  +dwidth = Binary.bit_length(denominator)
  +number = Binary.quantize(numerator, 0n, negative, False{})
  chosen(Bool.and(Nat.is_le(dwidth, 62n), Bool.and(finite_kind(Binary.kind(number)), Bool.or(Bool.not(fixed_integer(numerator, nwidth, negative)), Nat.is_le(dwidth, 53n)))), number, numerator, denominator, negative)

def after_fives(factored: Factored, twos: Nat, negative: Bool) -> Binary.Float:
  match factored:
    case FactorResult{digits, fives}:
      ratio(Bits.from_decimal(digits), Binary.pad(twos, Bits.from_decimal(Conversion.times_digit(fives, 5, [1]))), negative)

def after_twos(factored: Factored, scale: Nat, negative: Bool) -> Binary.Float:
  match factored:
    case FactorResult{digits, twos}:
      after_fives(strip_factor(scale, 5, digits), twos, negative)

def bounded(overflow: Bool, underflow: Bool, negative: Bool, digits: List<&2, U32>, +scale: Nat) -> Binary.Float:
  match overflow underflow:
    case True{} underflow:
      Binary.infinity(negative)
    case False{} True{}:
      Binary.zero(negative)
    case False{} False{}:
      after_twos(strip_factor(scale, 2, digits), scale, negative)

def canonical(negative: Bool, value: Decimal.Decimal) -> Binary.Float:
  match value:
    case Decimal.Exact{Nil{}, scale}:
      Binary.zero(False{})
    case Decimal.Exact{+head <> +rest, +scale}:
      +width = Nat.add(1n, Conversion.digit_length_into(rest, 0n))
      bounded(Nat.is_gt(Nat.sub(width, scale), 309n), Nat.is_ge(Nat.sub(scale, width), 324n), negative, head <> rest, scale)

def from_decimal(negative: Bool, value: Decimal.Decimal) -> Binary.Float:
  canonical(negative, Decimal.canonical(value))
