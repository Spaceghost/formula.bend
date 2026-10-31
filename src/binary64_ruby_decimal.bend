import Base
import ./binary64.bend as Binary
import ./binary64_decimal.bend as Conversion
import ./decimal.bend as Decimal

# Ruby 3.3.13 missing/dtoa.c, strtod's fractional-digit loop, stops
# accumulating after nd > DBL_DIG * 4. Pending zeros do not advance nd until
# the next nonzero digit. BigDecimal#to_f supplies normalized 0.<digits>eN
# text, so retain the first nonzero after the first sixty significant digits.
# This truncation is Ruby compatibility, not IEEE nearest/even conversion.
def after_nonzero(digits: List<&2, U32>) -> Nat:
  match digits:
    case Nil{}:
      0n
    case 0 <> rest:
      after_nonzero(rest)
    case digit <> rest:
      Conversion.digit_length_into(rest, 0n)

def dropped_digits(count: Nat, digits: List<&2, U32>) -> Nat:
  match count digits:
    case count Nil{}:
      0n
    case 0n digits:
      after_nonzero(digits)
    case 1n+rest digit <> tail:
      dropped_digits(rest, tail)

def restore(parts: Decimal.Removed, dropped: Nat, scale: Nat) -> Decimal.Decimal:
  match parts:
    case Decimal.Cut{digits, guard, sticky}:
      Decimal.Exact{Decimal.pad(dropped, digits), scale}

def truncate_digits(+dropped: Nat, digits: List<&2, U32>, scale: Nat) -> Decimal.Decimal:
  restore(Decimal.split_digits(dropped, digits, 0, False{}), dropped, scale)

def truncate_canonical(value: Decimal.Decimal) -> Decimal.Decimal:
  match value:
    case Decimal.Exact{+digits, scale}:
      truncate_digits(dropped_digits(60n, List.reverse(&2, U32, digits)), digits, scale)

def from_decimal(negative: Bool, value: Decimal.Decimal) -> Binary.Float:
  Conversion.from_decimal(negative, truncate_canonical(Decimal.canonical(value)))
