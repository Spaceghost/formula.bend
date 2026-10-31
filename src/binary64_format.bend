import Base
import ./binary64.bend as Binary
import ./binary64_decimal.bend as Conversion
import ./decimal.bend as Decimal

# Search decimal grids inside the exact binary rounding interval. Both adjacent
# decimal candidates are checked: powers of two have asymmetric intervals.
def exact_magnitude(value: Conversion.Exact) -> Decimal.Decimal:
  match value:
    case Conversion.Finite{negative, magnitude}:
      magnitude
    case value:
      Decimal.Exact{Nil{}, 0n}

def magnitude(value: Binary.Float) -> Decimal.Decimal:
  exact_magnitude(Conversion.to_exact(value))

def neighbor_words(value: U32 & U32, upward: Bool) -> Binary.Float:
  match value:
    case (+high, +low):
      Bool.pick(Binary.Float, upward,
        Binary.from_words(U32.add(high, Bool.to_u32(U32.is_eq(low, 4294967295))), U32.add(low, 1)),
        Binary.from_words(U32.sub(high, Bool.to_u32(U32.is_eq(low, 0))), U32.sub(low, 1)))

def neighbor(value: Binary.Float, upward: Bool) -> Binary.Float:
  neighbor_words(Binary.words(value), upward)

def upper_kind(kind: Binary.Classification, value: Binary.Float) -> Decimal.Decimal:
  match kind:
    case Binary.Infinite{}:
      Decimal.Exact{Conversion.times_digit(1024n, 2, [1]), 0n}
    case kind:
      magnitude(value)

def upper_neighbor(+value: Binary.Float) -> Decimal.Decimal:
  upper_kind(Binary.kind(value), value)

def endpoint(order: Cmp, even: Bool, lower: Bool) -> Bool:
  match order:
    case EQ{}:
      even
    case LT{}:
      Bool.not(lower)
    case GT{}:
      lower

def inside(+candidate: Decimal.Decimal, lower: Decimal.Decimal, upper: Decimal.Decimal, +even: Bool) -> Bool:
  +twice = Decimal.add(candidate, candidate)
  Bool.and(endpoint(Decimal.compare(twice, lower), even, True{}), endpoint(Decimal.compare(twice, upper), even, False{}))

def odd(digits: List<&2, U32>) -> Bool:
  match digits:
    case Nil{}:
      False{}
    case digit <> rest:
      U32.is_ne(U32.mod(digit, 2), 0)

def prefer_upper(parts: Decimal.Removed) -> Bool:
  match parts:
    case Decimal.Cut{digits, +guard, sticky}:
      Bool.or(U32.is_gt(guard, 5), Bool.and(U32.is_eq(guard, 5), Bool.or(sticky, odd(digits))))

def candidate(parts: Decimal.Removed, up: Bool, scale: Nat, before: Nat) -> Decimal.Decimal:
  Decimal.canonical(Decimal.rounded_parts(parts, Bool.pick(Decimal.Rounding, up, Decimal.TowardPositive{}, Decimal.TowardNegative{}), False{}, scale, before))

def search_other(fits: Bool, other: Decimal.Decimal, next: Unit -> Decimal.Decimal) -> Decimal.Decimal:
  match fits:
    case True{}:
      other
    case False{}:
      next(Unit{})

def search_first(fits: Bool, preferred: Decimal.Decimal, +other: Decimal.Decimal, lower: Decimal.Decimal, upper: Decimal.Decimal, even: Bool, next: Unit -> Decimal.Decimal) -> Decimal.Decimal:
  match fits:
    case True{}:
      preferred
    case False{}:
      search_other(inside(other, lower, upper, even), other, next)

def search(cut: Nat, +value: Decimal.Decimal, +lower: Decimal.Decimal, +upper: Decimal.Decimal, +even: Bool) -> Decimal.Decimal:
  match cut value:
    case 0n value:
      value
    case 1n+rest Decimal.Exact{+digits, +scale}:
      +rest = rest
      +cut = Nat.add(1n, rest)
      +parts = Decimal.split_digits(cut, digits, 0, False{})
      +up = prefer_upper(parts)
      +result_scale = Nat.sub(scale, cut)
      +before = Nat.sub(cut, scale)
      +preferred = candidate(parts, up, result_scale, before)
      search_first(inside(preferred, lower, upper, even), preferred, candidate(parts, Bool.not(up), result_scale, before), lower, upper, even, u => search(rest, Decimal.Exact{digits, scale}, lower, upper, even))

def length(value: Decimal.Decimal) -> Nat:
  match value:
    case Decimal.Exact{digits, scale}:
      Conversion.digit_length_into(digits, 0n)

def even(value: Binary.Float) -> Bool:
  match value:
    case Binary.Binary64{negative, exponent, high, low}:
      U32.is_eq(U32.and(low, 1), 0)

def absolute(value: Binary.Float) -> Binary.Float:
  match value:
    case Binary.Binary64{negative, exponent, high, low}:
      Binary.Binary64{False{}, exponent, high, low}

def shortest(+value: Binary.Float) -> Decimal.Decimal:
  +exact = magnitude(value)
  search(Nat.sub(length(exact), 1n), exact,
    Decimal.add(exact, magnitude(neighbor(value, False{}))),
    Decimal.add(exact, upper_neighbor(neighbor(value, True{}))),
    even(value))

def exponent_text(negative: Bool, +magnitude: Nat) -> String:
  Bool.pick(String, negative, "-", "+") ++ Bool.pick(String, Nat.is_lt(magnitude, 10n), "0", "") ++ Nat.show(magnitude)

def scientific(digits: String, exponent: String) -> String:
  match digits:
    case SCon{head, SNil{}}:
      SCon{head, ".0e" ++ exponent}
    case SCon{head, rest}:
      SCon{head, "." ++ rest ++ "e" ++ exponent}
    case SNil{}:
      "0.0"

def render_mode(scientific_mode: Bool, digits: List<&2, U32>, +scale: Nat, small: Bool, exponent: Nat) -> String:
  match scientific_mode:
    case True{}:
      scientific(Conversion.coefficient_text(Decimal.trim_low_zeros(digits), SNil{}), exponent_text(small, exponent))
    case False{}:
      Decimal.show(Decimal.Exact{digits, scale}) ++ Bool.pick(String, Nat.is_eq(scale, 0n), ".0", "")

def render_parts(value: Decimal.Decimal) -> String:
  match value:
    case Decimal.Exact{+digits, +scale}:
      +length = Conversion.digit_length_into(digits, 0n)
      +small = Nat.is_ge(scale, length)
      +exponent = Bool.pick(Nat, small, Nat.add(Nat.sub(scale, length), 1n), Nat.sub(Nat.sub(length, scale), 1n))
      render_mode(Bool.or(Bool.and(small, Nat.is_gt(exponent, 4n)), Bool.and(Nat.is_eq(scale, 0n), Bool.and(Bool.not(small), Nat.is_ge(exponent, 15n)))), digits, scale, small, exponent)

def finite(zero: Bool, +value: Binary.Float) -> String:
  match zero:
    case True{}:
      Bool.pick(String, Binary.sign(value), "-0.0", "0.0")
    case False{}:
      Bool.pick(String, Binary.sign(value), "-", "") ++ render_parts(shortest(absolute(value)))

def show_kind(kind: Binary.Classification, +value: Binary.Float) -> String:
  match kind:
    case Binary.NotANumber{}:
      "NaN"
    case Binary.Infinite{}:
      Bool.pick(String, Binary.sign(value), "-Infinity", "Infinity")
    case Binary.Finite{}:
      finite(Binary.is_zero(value), value)

def show(+value: Binary.Float) -> String:
  show_kind(Binary.kind(value), value)
