import Base
import ./decimal.bend as Decimal

type DigitResult is Data:
  QuotientDigit{digit: U32, remainder: List<&2, U32>}

def digit_choose(less: Bool, done: Unit -> DigitResult, next: Unit -> DigitResult) -> DigitResult:
  match less:
    case True{}:
      done(Unit{})
    case False{}:
      next(Unit{})

# A brought-down digit leaves remainder < 10*divisor, so at most nine
# subtractions are required. The fuel makes the bound explicit to the checker.
def digit(fuel: Nat, +remainder: List<&2, U32>, +divisor: List<&2, U32>, +count: U32) -> DigitResult:
  match fuel:
    case 0n:
      QuotientDigit{count, remainder}
    case 1n+p:
      digit_choose(Cmp.is_lt(Decimal.compare_digits(remainder, divisor)), u => QuotientDigit{count, remainder}, u => digit(p, Decimal.subtract_digits(remainder, divisor, 0), divisor, U32.add(count, 1)))

type DivisionResult is Data:
  Quotient{value: Decimal.Decimal, remainder: List<&2, U32>, divisor: List<&2, U32>}
  DivisionByZero{}

def continue_digit(result: DigitResult, next: U32 -> List<&2, U32> -> DivisionResult) -> DivisionResult:
  match result:
    case QuotientDigit{d, remainder}:
      next(d, remainder)

def long_divide(input: List<&2, U32>, +divisor: List<&2, U32>, remainder: List<&2, U32>, quotient: List<&2, U32>, scale: Nat) -> DivisionResult:
  match input:
    case Nil{}:
      Quotient{Decimal.Exact{Decimal.normalize_digits(quotient), scale}, Decimal.normalize_digits(remainder), divisor}
    case d <> rest:
      continue_digit(digit(10n, d <> remainder, divisor, 0), q => r => long_divide(rest, divisor, Decimal.normalize_digits(r), q <> quotient, scale))

def start(zero: Bool, numerator: List<&2, U32>, divisor: List<&2, U32>, scale: Nat) -> DivisionResult:
  match zero:
    case True{}:
      DivisionByZero{}
    case False{}:
      long_divide(List.reverse(&2, U32, numerator), divisor, Nil{}, Nil{}, scale)

# Truncated quotient at the requested number of fractional places, with an
# exact remainder. Rounding policy belongs to the caller.
def divide(a: Decimal.Decimal, b: Decimal.Decimal, +places: Nat) -> DivisionResult:
  match a b:
    case Decimal.Exact{x, sx} Decimal.Exact{+y, sy}:
      start(Decimal.is_zero_digits(y), Decimal.pad(Nat.add(places, sy), x), Decimal.pad(sx, y), places)

def show(result: DivisionResult) -> String:
  match result:
    case Quotient{value, remainder, divisor}:
      Decimal.show(value)
    case DivisionByZero{}:
      "Division by zero"

def needs_increment(mode: Decimal.Rounding, negative: Bool, +remainder: List<&2, U32>, divisor: List<&2, U32>) -> Bool:
  match mode:
    case Decimal.HalfAway{}:
      Bool.not(Cmp.is_lt(Decimal.compare_digits(Decimal.add_digits(remainder, remainder, 0), divisor)))
    case Decimal.TowardPositive{}:
      Bool.and(Bool.not(negative), Bool.not(Decimal.is_zero_digits(remainder)))
    case Decimal.TowardNegative{}:
      Bool.and(negative, Bool.not(Decimal.is_zero_digits(remainder)))

def round_coefficient(value: Decimal.Decimal, increment: Bool) -> Decimal.Decimal:
  match value increment:
    case Decimal.Exact{digits, s} True{}:
      Decimal.Exact{Decimal.add_digits(digits, [1], 0), s}
    case value False{}:
      value

# Ruby 3.3 / BigDecimal 3.1.5 allocates a quotient in base-10^9 limbs.
# Its operand-dependent precision is not a fixed number of decimal places.
def precision(value: Decimal.Decimal) -> Nat:
  match value:
    case Decimal.Exact{digits, +s}:
      +n = List.length(&2, U32, digits)
      Bool.pick(Nat, Nat.is_ge(n, s), n, s)

def positive_exponent(value: Decimal.Decimal) -> Nat:
  match value:
    case Decimal.Exact{digits, s}:
      Nat.div(Nat.add(Nat.sub(List.length(&2, U32, digits), s), 8n), 9n)

def negative_exponent(value: Decimal.Decimal) -> Nat:
  match value:
    case Decimal.Exact{digits, s}:
      Nat.div(Nat.sub(s, List.length(&2, U32, digits)), 9n)

def ruby_places_canonical(+a: Decimal.Decimal, +b: Decimal.Decimal) -> Nat:
  +pa = precision(a)
  +pb = precision(b)
  +p = Bool.pick(Nat, Nat.is_ge(pa, pb), pa, pb)
  mx = Bool.pick(Nat, Nat.is_ge(p, 16n), Nat.mul(p, 2n), 32n)
  words = Nat.div(Nat.add(mx, 8n), 9n)
  positive = Nat.mul(9n, Nat.add(words, Nat.add(positive_exponent(b), negative_exponent(a))))
  negative = Nat.mul(9n, Nat.add(positive_exponent(a), negative_exponent(b)))
  Nat.sub(positive, negative)

def ruby_places(a: Decimal.Decimal, b: Decimal.Decimal) -> Nat:
  ruby_places_canonical(Decimal.canonical(a), Decimal.canonical(b))
