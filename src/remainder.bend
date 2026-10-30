import Base
import ./decimal.bend as Decimal
import ./division.bend as Division

# Align exact coefficients, divide once, and adjust a nonzero remainder toward
# the divisor's sign. Ruby BigDecimal modulo returns positive zero.
type RemainderResult is Data:
  Remainder{negative: Bool, value: Decimal.Decimal}
  ZeroDivisor{}

def finish(result: Division.DivisionResult, +left_negative: Bool, +right_negative: Bool, places: Nat) -> RemainderResult:
  match result:
    case Division.DivisionByZero{}:
      ZeroDivisor{}
    case Division.Quotient{quotient, +remainder, +divisor}:
      +nonzero = Bool.not(Decimal.is_zero_digits(remainder))
      +adjust = Bool.and(Bool.xor(left_negative, right_negative), nonzero)
      Remainder{Bool.and(right_negative, nonzero), Decimal.canonical(Decimal.Exact{Bool.pick(List<&2, U32>, adjust, Decimal.subtract_digits(divisor, remainder, 0), remainder), places})}

def aligned(a: Decimal.Decimal, b: Decimal.Decimal, left_negative: Bool, right_negative: Bool) -> RemainderResult:
  match a b:
    case Decimal.Exact{x, +sx} Decimal.Exact{+y, +sy}:
      +places = Bool.pick(Nat, Nat.is_ge(sx, sy), sx, sy)
      finish(Division.start(Decimal.is_zero_digits(y), Decimal.pad(Nat.sub(places, sx), x), Decimal.pad(Nat.sub(places, sy), y), 0n), left_negative, right_negative, places)

def remainder(a: Decimal.Decimal, b: Decimal.Decimal, left_negative: Bool, right_negative: Bool) -> RemainderResult:
  aligned(Decimal.canonical(a), Decimal.canonical(b), left_negative, right_negative)
