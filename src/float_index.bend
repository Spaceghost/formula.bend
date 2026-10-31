import Base
import ./binary64.bend as Binary
import ./binary64_decimal.bend as Conversion
import ./binary64_format.bend as Format
import ./decimal.bend as Decimal

# Ruby 3.3's Array/String Float index conversion uses a signed 64-bit long.
# Its range error prints the original Float with C's %.10g, not Float#to_s.
type IndexResult is Data:
  Index{negative: Bool, magnitude: Decimal.Decimal}
  OutOfRange{message: String}

def odd(digits: List<&2, U32>) -> Bool:
  match digits:
    case Nil{}:
      False{}
    case head <> tail:
      U32.is_ne(U32.mod(head, 2), 0)

def ten_rounded(parts: Decimal.Removed) -> List<&2, U32>:
  match parts:
    case Decimal.Cut{+digits, +guard, sticky}:
      Bool.pick(List<&2, U32>, Bool.or(U32.is_gt(guard, 5), Bool.and(U32.is_eq(guard, 5), Bool.or(sticky, odd(digits)))), Decimal.add_digits(digits, [1], 0), digits)

def scientific(digits: String, exponent: String) -> String:
  match digits:
    case SCon{head, SNil{}}:
      SCon{head, "e+" ++ exponent}
    case SCon{head, rest}:
      SCon{head, "." ++ rest ++ "e+" ++ exponent}
    case SNil{}:
      "0"

def rounded_text(+digits: List<&2, U32>, dropped: Nat, scale: Nat) -> String:
  scientific(Conversion.coefficient_text(Decimal.trim_low_zeros(digits), SNil{}), Nat.show(Nat.sub(Nat.add(dropped, List.length(&2, U32, digits)), Nat.add(scale, 1n))))

def finite_text(value: Decimal.Decimal) -> String:
  match value:
    case Decimal.Exact{+digits, scale}:
      +dropped = Nat.sub(List.length(&2, U32, digits), 10n)
      rounded_text(ten_rounded(Decimal.split_digits(dropped, digits, 0, False{})), dropped, scale)

def range_text(kind: Binary.Classification, +value: Binary.Float) -> String:
  match kind:
    case Binary.Infinite{}:
      Bool.pick(String, Binary.sign(value), "-", "") ++ "Inf"
    case Binary.NotANumber{}:
      "NaN"
    case Binary.Finite{}:
      Bool.pick(String, Binary.sign(value), "-", "") ++ finite_text(Format.magnitude(value))

def range_error(+value: Binary.Float) -> IndexResult:
  OutOfRange{"float " ++ range_text(Binary.kind(value), value) ++ " out of range of integer"}

def bounded(fits: Bool, negative: Bool, magnitude: Decimal.Decimal, value: Binary.Float) -> IndexResult:
  match fits:
    case True{}:
      Index{negative, magnitude}
    case False{}:
      range_error(value)

def finite(+negative: Bool, +magnitude: Decimal.Decimal, value: Binary.Float) -> IndexResult:
  bounded(Bool.not(Cmp.is_gt(Decimal.compare(magnitude, Decimal.Exact{Bool.pick(U32, negative, 8, 7) <> [0, 8, 5, 7, 7, 4, 5, 8, 6, 3, 0, 2, 7, 3, 3, 2, 2, 9], 0n}))), negative, magnitude, value)

def projected(exact: Conversion.Exact, value: Binary.Float) -> IndexResult:
  match exact:
    case Conversion.Finite{negative, magnitude}:
      finite(negative, magnitude, value)
    case exact:
      range_error(value)

def convert(+value: Binary.Float) -> IndexResult:
  projected(Conversion.to_exact(value), value)
