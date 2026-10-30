import Base

# Exact unsigned base-10 coefficients, least-significant digit first.
# Each digit must be 0..9. Lists grow with the number, not the machine word size.
type Decimal is Data:
  Exact{digits: List<&2, U32>, scale: Nat}

def add_digits(a: List<&2, U32>, b: List<&2, U32>, +carry: U32) -> List<&2, U32>:
  match a b:
    case Nil{} Nil{}:
      Bool.pick(List<&2, U32>, U32.is_eq(carry, 0), Nil{}, [carry])
    case x <> xs Nil{}:
      +sum = U32.add(x, carry)
      U32.mod(sum, 10) <> add_digits(xs, Nil{}, U32.div(sum, 10))
    case Nil{} y <> ys:
      +sum = U32.add(y, carry)
      U32.mod(sum, 10) <> add_digits(Nil{}, ys, U32.div(sum, 10))
    case x <> xs y <> ys:
      +sum = U32.add(U32.add(x, y), carry)
      U32.mod(sum, 10) <> add_digits(xs, ys, U32.div(sum, 10))

def multiply_digit(a: List<&2, U32>, +digit: U32, +carry: U32) -> List<&2, U32>:
  match a:
    case Nil{}:
      Bool.pick(List<&2, U32>, U32.is_eq(carry, 0), Nil{}, [carry])
    case x <> xs:
      +product = U32.add(U32.mul(x, digit), carry)
      U32.mod(product, 10) <> multiply_digit(xs, digit, U32.div(product, 10))

def multiply_digits(a: List<&2, U32>, +b: List<&2, U32>) -> List<&2, U32>:
  match a:
    case Nil{}:
      Nil{}
    case x <> xs:
      row rest = multiply_digit(b, x, 0) multiply_digits(xs, b)
      add_digits(row, 0 <> rest, 0)

def pad(n: Nat, digits: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      digits
    case 1n+p:
      0 <> pad(p, digits)

def add(a: Decimal, b: Decimal) -> Decimal:
  match a b:
    case Exact{x, +sx} Exact{y, +sy}:
      Exact{add_digits(pad(Nat.sub(sy, sx), x), pad(Nat.sub(sx, sy), y), 0), Nat.add(sx, Nat.sub(sy, sx))}

def multiply(a: Decimal, b: Decimal) -> Decimal:
  match a b:
    case Exact{x, sx} Exact{y, sy}:
      Exact{multiply_digits(x, y), Nat.add(sx, sy)}

# Formatting keeps the declared decimal scale, including trailing fractional zeros.
def trim_leading(s: String) -> String:
  match s:
    case SNil{}:
      "0"
    case SCon{Chr{48}, rest}:
      trim_leading(rest)
    case s:
      s

def digit_text(digits: List<&2, U32>) -> String:
  match digits:
    case Nil{}:
      SNil{}
    case x <> xs:
      SCon{Chr{U32.add(48, x)}, digit_text(xs)}

def fractional(scale: Nat, digits: List<&2, U32>) -> String:
  match scale digits:
    case 0n digits:
      SCon{'.', String.reverse(trim_leading(String.reverse(digit_text(digits))))}
    case 1n+p Nil{}:
      SCon{'0', fractional(p, Nil{})}
    case 1n+p x <> xs:
      SCon{Chr{U32.add(48, x)}, fractional(p, xs)}

def show(value: Decimal) -> String:
  match value:
    case Exact{digits, 0n}:
      trim_leading(String.reverse(digit_text(digits)))
    case Exact{digits, 1n+p}:
      String.reverse(fractional(1n+p, digits))

def coefficient(digits: List<&2, U32>) -> Nat:
  match digits:
    case Nil{}:
      0n
    case x <> xs:
      Nat.add(U32.to_nat(x), Nat.mul(10n, coefficient(xs)))

def from_nat_pick(zero: Bool, next: Unit -> List<&2, U32>) -> List<&2, U32>:
  match zero:
    case True{}:
      Nil{}
    case False{}:
      next(Unit{})

def from_nat_go(fuel: Nat, +n: Nat) -> List<&2, U32>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+p:
      from_nat_pick(Nat.is_eq(n, 0n), u => U32.from_nat(Nat.mod(n, 10n)) <> from_nat_go(p, Nat.div(n, 10n)))

def from_nat(+n: Nat) -> Decimal:
  Exact{from_nat_go(n, n), 0n}

def scale(value: Decimal) -> Nat:
  match value:
    case Exact{digits, s}:
      s

# Comparison ignores redundant high zeros in little-endian coefficients.
def trim_high_reversed(digits: List<&2, U32>) -> List<&2, U32>:
  match digits:
    case 0 <> rest:
      trim_high_reversed(rest)
    case digits:
      digits

def compare_next(order: Cmp, next: Unit -> Cmp) -> Cmp:
  match order:
    case EQ{}:
      next(Unit{})
    case order:
      order

def compare_lex(a: List<&2, U32>, b: List<&2, U32>) -> Cmp:
  match a b:
    case Nil{} Nil{}:
      EQ{}
    case Nil{} b:
      LT{}
    case a Nil{}:
      GT{}
    case x <> xs y <> ys:
      compare_next(U32.cmp(x, y), u => compare_lex(xs, ys))

def compare_normalized(+a: List<&2, U32>, +b: List<&2, U32>) -> Cmp:
  compare_next(Nat.cmp(List.length(&2, U32, a), List.length(&2, U32, b)), u => compare_lex(a, b))

def compare_digits(a: List<&2, U32>, b: List<&2, U32>) -> Cmp:
  compare_normalized(trim_high_reversed(List.reverse(&2, U32, a)), trim_high_reversed(List.reverse(&2, U32, b)))

def compare(a: Decimal, b: Decimal) -> Cmp:
  match a b:
    case Exact{x, +sx} Exact{y, +sy}:
      compare_digits(pad(Nat.sub(sy, sx), x), pad(Nat.sub(sx, sy), y))

# Requires a >= b. Every intermediate stays below 20.
def subtract_digits(a: List<&2, U32>, b: List<&2, U32>, +borrow: U32) -> List<&2, U32>:
  match a b:
    case Nil{} b:
      Nil{}
    case +x <> xs Nil{}:
      U32.mod(U32.sub(U32.add(x, 10), borrow), 10) <> subtract_digits(xs, Nil{}, Bool.to_u32(U32.is_lt(x, borrow)))
    case +x <> xs y <> ys:
      +subtrahend = U32.add(y, borrow)
      U32.mod(U32.sub(U32.add(x, 10), subtrahend), 10) <> subtract_digits(xs, ys, Bool.to_u32(U32.is_lt(x, subtrahend)))

def subtract(a: Decimal, b: Decimal) -> Decimal:
  match a b:
    case Exact{x, +sx} Exact{y, +sy}:
      Exact{subtract_digits(pad(Nat.sub(sy, sx), x), pad(Nat.sub(sx, sy), y), 0), Nat.add(sx, Nat.sub(sy, sx))}

def is_zero_digits(digits: List<&2, U32>) -> Bool:
  match digits:
    case Nil{}:
      True{}
    case x <> xs:
      Bool.and(U32.is_eq(x, 0), is_zero_digits(xs))

def is_zero(value: Decimal) -> Bool:
  match value:
    case Exact{digits, s}:
      is_zero_digits(digits)

type Rounding is Data:
  HalfAway{}
  TowardPositive{}
  TowardNegative{}

type Removed is Data:
  Cut{kept: List<&2, U32>, guard: U32, sticky: Bool}

def split_digits(count: Nat, digits: List<&2, U32>, +last: U32, sticky: Bool) -> Removed:
  match count digits:
    case 0n digits:
      Cut{digits, last, sticky}
    case 1n+p Nil{}:
      split_digits(p, Nil{}, 0, Bool.or(sticky, U32.is_ne(last, 0)))
    case 1n+p x <> rest:
      split_digits(p, rest, x, Bool.or(sticky, U32.is_ne(last, 0)))

def increment(mode: Rounding, negative: Bool, +guard: U32, sticky: Bool) -> Bool:
  match mode:
    case HalfAway{}:
      U32.is_ge(guard, 5)
    case TowardPositive{}:
      Bool.and(Bool.not(negative), Bool.or(U32.is_ne(guard, 0), sticky))
    case TowardNegative{}:
      Bool.and(negative, Bool.or(U32.is_ne(guard, 0), sticky))

def rounded_parts(parts: Removed, mode: Rounding, negative: Bool, result_scale: Nat, before: Nat) -> Decimal:
  match parts:
    case Cut{+digits, guard, sticky}:
      Exact{pad(before, Bool.pick(List<&2, U32>, increment(mode, negative, guard, sticky), add_digits(digits, [1], 0), digits)), result_scale}

# target is fractional places; before is places to the left of the decimal point.
# Only one of target/before is nonzero. Sign remains in the caller.
def round(value: Decimal, +target: Nat, +before: Nat, mode: Rounding, negative: Bool) -> Decimal:
  match value:
    case Exact{digits, +s}:
      rounded_parts(split_digits(Nat.add(Nat.sub(s, target), before), digits, 0, False{}), mode, negative, Nat.sub(s, Nat.sub(s, target)), before)

def integer_digits(scale: Nat, digits: List<&2, U32>) -> List<&2, U32>:
  match scale digits:
    case 0n digits:
      digits
    case 1n+p Nil{}:
      Nil{}
    case 1n+p x <> rest:
      integer_digits(p, rest)

def normalize_digits(digits: List<&2, U32>) -> List<&2, U32>:
  List.reverse(&2, U32, trim_high_reversed(List.reverse(&2, U32, digits)))

def trim_fraction(digits: List<&2, U32>, s: Nat) -> Decimal:
  match digits s:
    case Nil{} s:
      Exact{Nil{}, 0n}
    case 0 <> rest 1n+p:
      trim_fraction(rest, p)
    case digits s:
      Exact{digits, s}

def canonical(value: Decimal) -> Decimal:
  match value:
    case Exact{digits, s}:
      trim_fraction(normalize_digits(digits), s)

def trim_low_zeros(digits: List<&2, U32>) -> List<&2, U32>:
  match digits:
    case 0 <> rest:
      trim_low_zeros(rest)
    case digits:
      digits

def ruby_exponent(+length: Nat, +scale: Nat) -> String:
  Bool.pick(String, Nat.is_ge(length, scale), Nat.show(Nat.sub(length, scale)), "-" ++ Nat.show(Nat.sub(scale, length)))

def ruby_digits(digits: List<&2, U32>, scale: Nat, negative: Bool) -> String:
  match digits:
    case Nil{}:
      Bool.pick(String, negative, "-0.0", "0.0")
    case +head <> +tail:
      Bool.pick(String, negative, "-", "") ++ "0." ++ String.reverse(digit_text(trim_low_zeros(head <> tail))) ++ "e" ++ ruby_exponent(List.length(&2, U32, head <> tail), scale)

# BigDecimal#to_s uses scientific form, separately from fixed-point display.
def ruby_show(value: Decimal, negative: Bool) -> String:
  match value:
    case Exact{digits, fractional_places}:
      ruby_digits(normalize_digits(digits), fractional_places, negative)
