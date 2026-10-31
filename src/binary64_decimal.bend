import Base
import ./binary64.bend as Binary
import ./bits.bend as Bits
import ./decimal.bend as Decimal

type Exact is Data:
  Finite{negative: Bool, magnitude: Decimal.Decimal}
  Infinite{negative: Bool}
  NotANumber{}

def times_digit(count: Nat, +digit: U32, digits: List<&2, U32>) -> List<&2, U32>:
  match count:
    case 0n:
      digits
    case 1n+rest:
      times_digit(rest, digit, Decimal.multiply_digit(digits, digit, 0))

def exact_magnitude(integer: Bool, digits: List<&2, U32>, +shift: Nat) -> Decimal.Decimal:
  match integer:
    case True{}:
      Decimal.canonical(Decimal.Exact{times_digit(Nat.sub(shift, 1074n), 2, digits), 0n})
    case False{}:
      Decimal.canonical(Decimal.Exact{times_digit(Nat.sub(1074n, shift), 5, digits), Nat.sub(1074n, shift)})

def exact_coefficient(value: Decimal.Decimal, +shift: Nat) -> Decimal.Decimal:
  match value:
    case Decimal.Exact{digits, scale}:
      exact_magnitude(Nat.is_ge(shift, 1074n), digits, shift)

def exact_bits(bits: List<&2, Bool>, +shift: Nat) -> Decimal.Decimal:
  match bits:
    case Nil{}:
      Decimal.Exact{Nil{}, 0n}
    case False{} <> rest:
      exact_bits(rest, Nat.add(shift, 1n))
    case bits:
      exact_coefficient(Bits.magnitude(False{}, bits), shift)

def exact_finite(zero: Bool, +value: Binary.Float) -> Exact:
  match zero:
    case True{}:
      Finite{Binary.sign(value), Decimal.Exact{Nil{}, 0n}}
    case False{}:
      Finite{Binary.sign(value), exact_bits(Binary.significand(value), Binary.shift(value))}

def to_exact_kind(classification: Binary.Classification, +value: Binary.Float) -> Exact:
  match classification:
    case Binary.NotANumber{}:
      NotANumber{}
    case Binary.Infinite{}:
      Infinite{Binary.sign(value)}
    case Binary.Finite{}:
      exact_finite(Binary.is_zero(value), value)

def to_exact(+value: Binary.Float) -> Exact:
  to_exact_kind(Binary.kind(value), value)

def digit_length_into(digits: List<&2, U32>, length: Nat) -> Nat:
  match digits:
    case Nil{}:
      length
    case digit <> rest:
      digit_length_into(rest, Nat.add(length, 1n))

def converted_quotient(parts: List<&2, Bool> & List<&2, Bool>, negative: Bool, discarded: Bool) -> Binary.Float:
  (quotient, remainder) = parts
  Binary.quantize(quotient, 1075n, negative, Bool.or(discarded, Bool.not(List.is_empty(&2, Bool, remainder))))

def retained_ratio(value: Decimal.Decimal, negative: Bool, discarded: Bool) -> Binary.Float:
  match value:
    case Decimal.Exact{digits, scale}:
      converted_quotient(Binary.divide_walk(List.reverse(&2, Bool, Binary.pad(1075n, Bits.from_decimal(digits))), Bits.from_decimal(Decimal.pad(scale, [1])), Binary.Step{False{}, Nil{}}, Nil{}), negative, discarded)

# Every binary64 rounding midpoint is a multiple of 2^-1075 and has a
# terminating decimal at or before fractional place 1075. Decimal truncation
# beyond that grid cannot cross a midpoint. A nonzero omitted tail only needs
# to break an exact tie upward in magnitude; it is retained as a sticky bit.
def from_retained(parts: Decimal.Removed, scale: Nat, negative: Bool) -> Binary.Float:
  match parts:
    case Decimal.Cut{digits, guard, sticky}:
      # Cropping can expose a long run of low zeros. Cancel those powers of
      # ten before binary division, retaining the ORIGINAL omitted-tail bit.
      retained_ratio(Decimal.canonical(Decimal.Exact{digits, scale}), negative, Bool.or(U32.is_ne(guard, 0), sticky))

def from_bounded(overflow: Bool, underflow: Bool, negative: Bool, digits: List<&2, U32>, +scale: Nat) -> Binary.Float:
  match overflow underflow:
    case True{} underflow:
      Binary.infinity(negative)
    case False{} True{}:
      Binary.zero(negative)
    case False{} False{}:
      from_retained(Decimal.split_digits(Nat.sub(scale, 1075n), digits, 0, False{}), Nat.sub(scale, Nat.sub(scale, 1075n)), negative)

def from_parts(negative: Bool, digits: List<&2, U32>, +scale: Nat) -> Binary.Float:
  match digits:
    case Nil{}:
      Binary.zero(negative)
    case +head <> +rest:
      +length = Nat.add(1n, digit_length_into(rest, 0n))
      from_bounded(Nat.is_gt(Nat.sub(length, scale), 309n), Nat.is_ge(Nat.sub(scale, length), 324n), negative, head <> rest, scale)

def from_canonical(negative: Bool, value: Decimal.Decimal) -> Binary.Float:
  match value:
    case Decimal.Exact{digits, scale}:
      from_parts(negative, digits, scale)

def from_decimal(negative: Bool, value: Decimal.Decimal) -> Binary.Float:
  from_canonical(negative, Decimal.canonical(value))

def from_exact(value: Exact) -> Binary.Float:
  match value:
    case Finite{negative, magnitude}:
      from_decimal(negative, magnitude)
    case Infinite{negative}:
      Binary.infinity(negative)
    case NotANumber{}:
      Binary.nan()

def coefficient_text(digits: List<&2, U32>, text: String) -> String:
  match digits:
    case Nil{}:
      text
    case digit <> rest:
      coefficient_text(rest, SCon{Chr{U32.add(48, digit)}, text})

def prepend_reversed(text: String, suffix: String) -> String:
  match text:
    case SNil{}:
      suffix
    case SCon{head, rest}:
      prepend_reversed(rest, SCon{head, suffix})

def append(text: String, suffix: String) -> String:
  prepend_reversed(String.reverse(text), suffix)

def finite_snapshot(negative: Bool, value: Decimal.Decimal) -> String:
  match value:
    case Decimal.Exact{Nil{}, scale}:
      "finite:" ++ Bool.pick(String, negative, "-", "+") ++ "0:0"
    case Decimal.Exact{digits, scale}:
      "finite:" ++ Bool.pick(String, negative, "-", "+") ++ append(coefficient_text(digits, SNil{}), ":" ++ Nat.show(scale))

def snapshot(value: Exact) -> String:
  match value:
    case Finite{negative, magnitude}:
      finite_snapshot(negative, magnitude)
    case Infinite{negative}:
      Bool.pick(String, negative, "negative-infinity", "positive-infinity")
    case NotANumber{}:
      "nan"
