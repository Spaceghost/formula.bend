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
