import Base
import ./decimal.bend as Decimal

type BitwiseOperation is Data:
  BitOr{}
  BitAnd{}
  ShiftLeft{}
  ShiftRight{}

type BitLogic is Data:
  OrBits{}
  AndBits{}
  AndNotBits{}

# A negative integer is the complement of code, so -1 has an empty code.
# This gives infinite sign extension without choosing a machine word width.
type SignedBits is Data:
  Encoded{negative: Bool, code: List<&2, Bool>}

type BitwiseResult is Data:
  IntegerResult{negative: Bool, value: Decimal.Decimal}
  ShiftTooWide{}

def reverse_into(bits: List<&2, Bool>, tail: List<&2, Bool>) -> List<&2, Bool>:
  match bits:
    case Nil{}:
      tail
    case head <> rest:
      reverse_into(rest, head <> tail)

def drop_high_zero(bits: List<&2, Bool>) -> List<&2, Bool>:
  match bits:
    case False{} <> rest:
      drop_high_zero(rest)
    case bits:
      bits

def normalize(bits: List<&2, Bool>) -> List<&2, Bool>:
  List.reverse(&2, Bool, drop_high_zero(List.reverse(&2, Bool, bits)))

def add_walk(a: List<&2, Bool>, b: List<&2, Bool>, +carry: Bool, reversed: List<&2, Bool>) -> List<&2, Bool>:
  match a b:
    case Nil{} Nil{}:
      reverse_into(reversed, Bool.pick(List<&2, Bool>, carry, [True{}], Nil{}))
    case +x <> xs Nil{}:
      add_walk(xs, Nil{}, Bool.and(x, carry), Bool.xor(x, carry) <> reversed)
    case Nil{} +y <> ys:
      add_walk(Nil{}, ys, Bool.and(y, carry), Bool.xor(y, carry) <> reversed)
    case +x <> xs +y <> ys:
      add_walk(xs, ys, Bool.or(Bool.and(x, y), Bool.and(carry, Bool.or(x, y))), Bool.xor(x, Bool.xor(y, carry)) <> reversed)

def add(a: List<&2, Bool>, b: List<&2, Bool>) -> List<&2, Bool>:
  normalize(add_walk(a, b, False{}, Nil{}))

def digit_bits(+digit: U32) -> List<&2, Bool>:
  [U32.is_ne(U32.and(digit, 1), 0), U32.is_ne(U32.and(digit, 2), 0), U32.is_ne(U32.and(digit, 4), 0), U32.is_ne(U32.and(digit, 8), 0)]

def times_ten(+bits: List<&2, Bool>) -> List<&2, Bool>:
  add(False{} <> bits, False{} <> False{} <> False{} <> bits)

def decimal_walk(digits: List<&2, U32>, bits: List<&2, Bool>) -> List<&2, Bool>:
  match digits:
    case Nil{}:
      bits
    case digit <> rest:
      decimal_walk(rest, add(times_ten(bits), digit_bits(digit)))

def from_decimal(digits: List<&2, U32>) -> List<&2, Bool>:
  decimal_walk(List.reverse(&2, U32, digits), Nil{})

def encode_nonzero(negative: Bool, digits: List<&2, U32>) -> SignedBits:
  match negative:
    case False{}:
      Encoded{False{}, from_decimal(digits)}
    case True{}:
      Encoded{True{}, from_decimal(Decimal.subtract_digits(digits, [1], 0))}

def encode_zero(zero: Bool, negative: Bool, digits: List<&2, U32>) -> SignedBits:
  match zero:
    case True{}:
      Encoded{False{}, Nil{}}
    case False{}:
      encode_nonzero(negative, digits)

def encode(negative: Bool, value: Decimal.Decimal) -> SignedBits:
  match value:
    case Decimal.Exact{+digits, places}:
      encode_zero(Decimal.is_zero_digits(digits), negative, digits)

def decimal_bit(bit: Bool, digits: List<&2, U32>) -> List<&2, U32>:
  match bit:
    case False{}:
      Decimal.multiply_digit(digits, 2, 0)
    case True{}:
      Decimal.add_digits(Decimal.multiply_digit(digits, 2, 0), [1], 0)

def coefficient_walk(bits: List<&2, Bool>, digits: List<&2, U32>) -> List<&2, U32>:
  match bits:
    case Nil{}:
      Decimal.normalize_digits(digits)
    case bit <> rest:
      coefficient_walk(rest, decimal_bit(bit, digits))

def magnitude(negative: Bool, code: List<&2, Bool>) -> Decimal.Decimal:
  +digits = coefficient_walk(List.reverse(&2, Bool, code), Nil{})
  Decimal.Exact{Bool.pick(List<&2, U32>, negative, Decimal.add_digits(digits, [1], 0), digits), 0n}

def result(value: SignedBits) -> BitwiseResult:
  match value:
    case Encoded{+negative, code}:
      IntegerResult{negative, magnitude(negative, code)}

def combine_bit(kind: BitLogic, a: Bool, b: Bool) -> Bool:
  match kind:
    case OrBits{}:
      Bool.or(a, b)
    case AndBits{}:
      Bool.and(a, b)
    case AndNotBits{}:
      Bool.and(a, Bool.not(b))

def combine_walk(a: List<&2, Bool>, b: List<&2, Bool>, +kind: BitLogic, reversed: List<&2, Bool>) -> List<&2, Bool>:
  match a b:
    case Nil{} Nil{}:
      normalize(reverse_into(reversed, Nil{}))
    case x <> xs Nil{}:
      combine_walk(xs, Nil{}, kind, combine_bit(kind, x, False{}) <> reversed)
    case Nil{} y <> ys:
      combine_walk(Nil{}, ys, kind, combine_bit(kind, False{}, y) <> reversed)
    case x <> xs y <> ys:
      combine_walk(xs, ys, kind, combine_bit(kind, x, y) <> reversed)

def combine(a: List<&2, Bool>, b: List<&2, Bool>, kind: BitLogic) -> List<&2, Bool>:
  combine_walk(a, b, kind, Nil{})

def logical(kind: BitwiseOperation, a: SignedBits, b: SignedBits) -> SignedBits:
  match kind a b:
    case BitOr{} Encoded{False{}, x} Encoded{False{}, y}:
      Encoded{False{}, combine(x, y, OrBits{})}
    case BitOr{} Encoded{True{}, x} Encoded{True{}, y}:
      Encoded{True{}, combine(x, y, AndBits{})}
    case BitOr{} Encoded{True{}, x} Encoded{False{}, y}:
      Encoded{True{}, combine(x, y, AndNotBits{})}
    case BitOr{} Encoded{False{}, x} Encoded{True{}, y}:
      Encoded{True{}, combine(y, x, AndNotBits{})}
    case BitAnd{} Encoded{False{}, x} Encoded{False{}, y}:
      Encoded{False{}, combine(x, y, AndBits{})}
    case BitAnd{} Encoded{True{}, x} Encoded{True{}, y}:
      Encoded{True{}, combine(x, y, OrBits{})}
    case BitAnd{} Encoded{True{}, x} Encoded{False{}, y}:
      Encoded{False{}, combine(y, x, AndNotBits{})}
    case BitAnd{} Encoded{False{}, x} Encoded{True{}, y}:
      Encoded{False{}, combine(x, y, AndNotBits{})}
    case kind a b:
      a

def drop_low(bits: List<&2, Bool>, count: Nat) -> List<&2, Bool>:
  match bits count:
    case bits 0n:
      bits
    case Nil{} count:
      Nil{}
    case bit <> rest 1n+p:
      drop_low(rest, p)

def right_bounded(enough: Bool, negative: Bool, code: List<&2, Bool>, digits: List<&2, U32>) -> SignedBits:
  match enough:
    case True{}:
      Encoded{negative, Nil{}}
    case False{}:
      Encoded{negative, drop_low(code, Decimal.coefficient(digits))}

def shift_right(value: SignedBits, count: Decimal.Decimal) -> BitwiseResult:
  match value count:
    case Encoded{negative, +code} Decimal.Exact{+digits, places}:
      result(right_bounded(Bool.not(Cmp.is_lt(Decimal.compare(Decimal.Exact{digits, 0n}, Decimal.from_nat(List.length(&2, Bool, code))))), negative, code, digits))

def repeated(times: Nat, +bits: List<&2, Bool>, tail: List<&2, Bool>) -> List<&2, Bool>:
  match times:
    case 0n:
      tail
    case 1n+p:
      repeated(p, bits, List.append(&2, Bool, bits, tail))

def padding_walk(digits: List<&2, U32>, +fill: Bool, padding: List<&2, Bool>) -> List<&2, Bool>:
  match digits:
    case Nil{}:
      padding
    case digit <> rest:
      padding_walk(rest, fill, repeated(10n, padding, repeated(U32.to_nat(digit), [fill], Nil{})))

def all_ones(bits: List<&2, Bool>) -> Bool:
  match bits:
    case Nil{}:
      True{}
    case False{} <> rest:
      False{}
    case True{} <> rest:
      all_ones(rest)

def ruby_limb_count(+negative: Bool, +code: List<&2, Bool>) -> Nat:
  Nat.div(Nat.add(Nat.add(List.length(&2, Bool, code), Bool.pick(Nat, Bool.and(negative, all_ones(code)), 1n, 0n)), 31n), 32n)

# The pinned Ruby profile uses 64-bit long and 32-bit Bignum digits. Compare
# its allocation-width bound before building padding; never narrow the count.
def shift_limit_for(limbs: Decimal.Decimal) -> Decimal.Decimal:
  match limbs:
    case Decimal.Exact{digits, places}:
      Decimal.Exact{Decimal.subtract_digits(Decimal.multiply_digit(Decimal.subtract_digits([1, 5, 9, 3, 9, 6, 3, 1, 2, 9, 0, 0, 3, 4, 8, 5, 0, 3, 2], digits, 0), 32, 0), [1], 0), 0n}

def shift_limit(negative: Bool, code: List<&2, Bool>) -> Decimal.Decimal:
  shift_limit_for(Decimal.from_nat(ruby_limb_count(negative, code)))

def left_checked(fits: Bool, +negative: Bool, code: List<&2, Bool>, digits: List<&2, U32>) -> BitwiseResult:
  match fits:
    case False{}:
      ShiftTooWide{}
    case True{}:
      result(Encoded{negative, List.append(&2, Bool, padding_walk(List.reverse(&2, U32, digits), negative, Nil{}), code)})

def shift_left(value: SignedBits, +count: Decimal.Decimal) -> BitwiseResult:
  match value count:
    case Encoded{False{}, Nil{}} count:
      IntegerResult{False{}, Decimal.from_nat(0n)}
    case Encoded{+negative, +code} Decimal.Exact{digits, places}:
      left_checked(Bool.not(Cmp.is_gt(Decimal.compare(count, shift_limit(negative, code)))), negative, code, digits)

def shift(left: Bool, value: SignedBits, count: Decimal.Decimal) -> BitwiseResult:
  match left:
    case True{}:
      shift_left(value, count)
    case False{}:
      shift_right(value, count)

def calculate(kind: BitwiseOperation, +left_negative: Bool, +left: Decimal.Decimal, right_negative: Bool, right: Decimal.Decimal) -> BitwiseResult:
  match kind:
    case ShiftLeft{}:
      shift(Bool.not(right_negative), encode(left_negative, left), right)
    case ShiftRight{}:
      shift(right_negative, encode(left_negative, left), right)
    case kind:
      result(logical(kind, encode(left_negative, left), encode(right_negative, right)))
