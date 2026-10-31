import Base
import ./binary64.bend as Binary
import ./binary64_decimal.bend as Conversion
import ./binary64_format.bend as Format
import ./decimal.bend as Decimal

type Profile is Data:
  Implicit{}
  ShortestText{}

# BigDecimal 3.1.5's implicit Float coercion uses dtoa mode zero, then
# truncates a seventeenth significant digit (rather than rounding it).
# BigDecimal(float.to_s, 16) parses all text digits and follows another path.
def restore(parts: Decimal.Removed, +dropped: Nat, +scale: Nat) -> Decimal.Decimal:
  match parts:
    case Decimal.Cut{digits, guard, sticky}:
      Decimal.canonical(Decimal.Exact{Decimal.pad(Nat.sub(dropped, scale), digits), Nat.sub(scale, dropped)})

def truncate_digits(+dropped: Nat, digits: List<&2, U32>, scale: Nat) -> Decimal.Decimal:
  restore(Decimal.split_digits(dropped, digits, 0, False{}), dropped, scale)

def truncate(value: Decimal.Decimal) -> Decimal.Decimal:
  match value:
    case Decimal.Exact{+digits, scale}:
      truncate_digits(Nat.sub(Conversion.digit_length_into(digits, 0n), 16n), digits, scale)

def select(profile: Profile, value: Decimal.Decimal) -> Decimal.Decimal:
  match profile:
    case Implicit{}:
      truncate(value)
    case ShortestText{}:
      value

def finite(zero: Bool, profile: Profile, +value: Binary.Float) -> Conversion.Exact:
  match zero:
    case True{}:
      Conversion.Finite{Binary.sign(value), Decimal.Exact{Nil{}, 0n}}
    case False{}:
      Conversion.Finite{Binary.sign(value), select(profile, Format.shortest(Format.absolute(value)))}

def classified(kind: Binary.Classification, profile: Profile, +value: Binary.Float) -> Conversion.Exact:
  match kind:
    case Binary.NotANumber{}:
      Conversion.NotANumber{}
    case Binary.Infinite{}:
      Conversion.Infinite{Binary.sign(value)}
    case Binary.Finite{}:
      finite(Binary.is_zero(value), profile, value)

def from_float(profile: Profile, +value: Binary.Float) -> Conversion.Exact:
  classified(Binary.kind(value), profile, value)
