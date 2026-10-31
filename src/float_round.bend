import Base
import ./decimal.bend as Decimal
import ./binary64.bend as Binary
import ./binary64_decimal.bend as Conversion
import ./binary64_bigdecimal.bend as BigDecimal
import ./binary64_ruby_decimal.bend as RubyDecimal
import ./numeric_float.bend as Numeric
import ./rational_float.bend as Rational
import ./bits.bend as Bits

type Exponent is Data:
  BinaryExponent{positive: Bool, magnitude: Nat}

def domain(value: Binary.Float) -> Numeric.CalculationResult:
  Numeric.NativeRejected{"FloatDomainError", Numeric.render(Numeric.Floating{value})}

def integer_projection(value: Conversion.Exact) -> Numeric.CalculationResult:
  match value:
    case Conversion.Finite{negative, Decimal.Exact{digits, scale}}:
      Numeric.Calculated{Numeric.exact_result(Numeric.IntegerKind{}, negative, Decimal.Exact{Decimal.normalize_digits(Decimal.integer_digits(scale, digits)), 0n})}
    case Conversion.Infinite{negative}:
      domain(Binary.infinity(negative))
    case Conversion.NotANumber{}:
      domain(Binary.nan())

def integral_float(value: Conversion.Exact) -> Binary.Float:
  match value:
    case Conversion.Finite{+negative, magnitude}:
      Conversion.from_decimal(negative, Decimal.round(magnitude, 0n, 0n, Decimal.HalfAway{}, negative))
    case value:
      Conversion.from_exact(value)

def correction_condition(order: Maybe<&2, Cmp>, negative: Bool) -> Bool:
  match order:
    case Some{+order}:
      Bool.pick(Bool, negative, Bool.not(Cmp.is_lt(order)), Bool.not(Cmp.is_gt(order)))
    case None{}:
      False{}

def corrected(increment: Bool, +negative: Bool, rounded: Binary.Float, scale: Binary.Float) -> Binary.Float:
  match increment:
    case True{}:
      Binary.divide(Binary.add(rounded, Binary.Binary64{negative, 1023, 0, 0}), scale)
    case False{}:
      Binary.divide(rounded, scale)

# Ruby's round_half_up: round(x*s), then test the half-step back in x's
# original domain. The correction uses binary64 operations, not decimal text.
def small_round(+value: Binary.Float, +scale: Binary.Float) -> Binary.Float:
  +negative = Binary.sign(value)
  +rounded = integral_float(Conversion.to_exact(Binary.multiply(value, scale)))
  corrected(correction_condition(Binary.compare(Binary.divide(Binary.add(rounded, Binary.Binary64{negative, 1022, 0, 0}), scale), value), negative), negative, rounded, scale)

def rational_rounded(value: Conversion.Exact, target: Nat) -> Numeric.CalculationResult:
  match value:
    case Conversion.Finite{+negative, magnitude}:
      Numeric.Calculated{Numeric.Floating{Rational.from_decimal(negative, Decimal.round(magnitude, target, 0n, Decimal.HalfAway{}, negative))}}
    case value:
      Numeric.Calculated{Numeric.Floating{Conversion.from_exact(value)}}

def positive_path(rational: Bool, target: Nat, value: Binary.Float) -> Numeric.CalculationResult:
  match rational:
    case True{}:
      rational_rounded(Conversion.to_exact(value), target)
    case False{}:
      Numeric.Calculated{Numeric.Floating{small_round(value, Binary.quantize(Bits.from_decimal(Decimal.pad(target, [1])), 0n, False{}, False{}))}}

def positive_bounded(overflow: Bool, underflow: Bool, +target: Nat, value: Binary.Float) -> Numeric.CalculationResult:
  match overflow underflow:
    case True{} underflow:
      Numeric.Calculated{Numeric.Floating{value}}
    case False{} True{}:
      Numeric.Calculated{Numeric.Floating{Binary.zero(False{})}}
    case False{} False{}:
      positive_path(Nat.is_gt(target, 14n), target, value)

def positive_exponent(exponent: Exponent, +target: Nat, value: Binary.Float) -> Numeric.CalculationResult:
  match exponent:
    case BinaryExponent{+positive, +magnitude}:
      positive_bounded(Bool.pick(Bool, positive, Nat.is_ge(target, Nat.sub(17n, Nat.div(magnitude, 4n))), Nat.is_ge(target, Nat.add(18n, Nat.div(magnitude, 3n)))), Bool.and(Bool.not(positive), Nat.is_lt(target, Nat.div(magnitude, 4n))), target, value)

def exponent(value: Binary.Float) -> Exponent:
  match value:
    case Binary.Binary64{negative, 0, high, low}:
      BinaryExponent{False{}, Nat.sub(1074n, Binary.bit_length(Binary.significand(Binary.Binary64{negative, 0, high, low})))}
    case Binary.Binary64{negative, word, high, low}:
      +field = U32.to_nat(word)
      BinaryExponent{Nat.is_gt(field, 1022n), Bool.pick(Nat, Nat.is_gt(field, 1022n), Nat.sub(field, 1022n), Nat.sub(1022n, field))}

def integer_rounded(value: Conversion.Exact, before: Nat) -> Numeric.CalculationResult:
  match value:
    case Conversion.Finite{+negative, magnitude}:
      Numeric.Calculated{Numeric.exact_result(Numeric.IntegerKind{}, negative, Decimal.round(magnitude, 0n, before, Decimal.HalfAway{}, negative))}
    case value:
      integer_projection(value)

def half_round(positive: Bool, +target: Nat, before: Nat, +value: Binary.Float) -> Numeric.CalculationResult:
  match positive:
    case True{}:
      positive_exponent(exponent(value), target, value)
    case False{}:
      integer_rounded(Conversion.to_exact(value), before)

def directional_result(integer: Bool, +value: Binary.Float) -> Numeric.CalculationResult:
  match integer:
    case True{}:
      integer_projection(Conversion.to_exact(value))
    case False{}:
      Numeric.Calculated{Numeric.Floating{value}}

def directional_projection(value: Conversion.Exact, +target: Nat, before: Nat, mode: Decimal.Rounding) -> Numeric.CalculationResult:
  match value:
    case Conversion.Finite{+negative, magnitude}:
      directional_result(Nat.is_eq(target, 0n), RubyDecimal.from_decimal(negative, Decimal.round(magnitude, target, before, mode, negative)))
    case value:
      directional_result(Nat.is_eq(target, 0n), Conversion.from_exact(value))

def large_direction(mode: Decimal.Rounding, negative: Bool) -> Numeric.CalculationResult:
  match mode negative:
    case Decimal.TowardPositive{} False{}:
      domain(Binary.infinity(False{}))
    case Decimal.TowardNegative{} True{}:
      domain(Binary.infinity(True{}))
    case mode negative:
      Numeric.Calculated{Numeric.Exact{Numeric.IntegerKind{}, False{}, Decimal.Exact{Nil{}, 0n}}}

def finite_mode(mode: Decimal.Rounding, +target: Nat, before: Nat, +value: Binary.Float) -> Numeric.CalculationResult:
  match mode:
    case Decimal.HalfAway{}:
      half_round(Nat.is_gt(target, 0n), target, before, value)
    case mode:
      directional_projection(BigDecimal.from_float(BigDecimal.ShortestText{}, value), target, before, mode)

def finite_bounded(huge_before: Bool, huge_target: Bool, mode: Decimal.Rounding, target: Nat, before: Nat, value: Binary.Float) -> Numeric.CalculationResult:
  match huge_before huge_target mode:
    case True{} huge_target Decimal.HalfAway{}:
      Numeric.Calculated{Numeric.Exact{Numeric.IntegerKind{}, False{}, Decimal.Exact{Nil{}, 0n}}}
    case True{} huge_target mode:
      large_direction(mode, Binary.sign(value))
    case False{} True{} Decimal.HalfAway{}:
      finite_mode(Decimal.HalfAway{}, target, before, value)
    case False{} True{} mode:
      Numeric.Calculated{Numeric.Floating{value}}
    case False{} False{} mode:
      finite_mode(mode, target, before, value)

def finite_zero(zero: Bool, mode: Decimal.Rounding, +target: Nat, +before: Nat, value: Binary.Float) -> Numeric.CalculationResult:
  match zero:
    case True{}:
      directional_result(Nat.is_eq(target, 0n), value)
    case False{}:
      finite_bounded(Nat.is_ge(before, 309n), Nat.is_ge(target, 325n), mode, target, before, value)

def classified(kind: Binary.Classification, mode: Decimal.Rounding, target: Nat, before: Nat, +value: Binary.Float) -> Numeric.CalculationResult:
  match kind:
    case Binary.Finite{}:
      finite_zero(Binary.is_zero(value), mode, target, before, value)
    case kind:
      directional_result(Nat.is_eq(target, 0n), value)

def checked(valid: Bool, mode: Decimal.Rounding, +target: Nat, +before: Nat, +value: Binary.Float) -> Numeric.CalculationResult:
  match valid:
    case True{}:
      classified(Binary.kind(value), mode, target, before, value)
    case False{}:
      Numeric.NativeRejected{"RangeError", "integer " ++ Bool.pick(String, Nat.is_gt(before, 0n), "-" ++ Nat.show(before) ++ " too small", Nat.show(target) ++ " too big") ++ " to convert to `int'"}

def round(mode: Decimal.Rounding, +target: Nat, +before: Nat, value: Binary.Float) -> Numeric.CalculationResult:
  checked(Bool.and(Nat.is_le(target, 2147483647n), Nat.is_le(before, 2147483648n)), mode, target, before, value)
