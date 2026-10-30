import Base
import ./decimal.bend as Decimal

# Small integers use Nat; larger integers and decimals use exact digit lists.
type Value is Data:
  Number{value: Nat}
  DecimalNumber{value: Decimal.Decimal}
  NegativeNumber{value: Decimal.Decimal}
  Logical{value: Bool}
  Failure{message: String}

type Expr is Data:
  Literal{value: Value}
  Variable{name: String}
  Add{left: Expr, right: Expr}
  Multiply{left: Expr, right: Expr}
  If{condition: Expr, yes: Expr, no: Expr}
  Not{operand: Expr}
  Negate{operand: Expr}
  Subtract{left: Expr, right: Expr}
  Round{operand: Expr, places: Expr, mode: Decimal.Rounding}

def compact_pick(value: Decimal.Decimal, small: Bool) -> Value:
  match value small:
    case Decimal.Exact{digits, 0n} True{}:
      Number{Decimal.coefficient(digits)}
    case value small:
      DecimalNumber{value}

def compact(value: Decimal.Decimal) -> Value:
  match value:
    case Decimal.Exact{+digits, +scale}:
      compact_pick(Decimal.Exact{digits, scale}, Bool.and(Nat.is_eq(scale, 0n), Nat.is_le(List.length(&2, U32, digits), 3n)))

def negative_pick(value: Decimal.Decimal, zero: Bool) -> Value:
  match zero:
    case True{}:
      compact(value)
    case False{}:
      NegativeNumber{value}

def negative(+value: Decimal.Decimal) -> Value:
  negative_pick(value, Decimal.is_zero(value))

def difference_pick(order: Cmp, +a: Decimal.Decimal, +b: Decimal.Decimal) -> Value:
  match order:
    case LT{}:
      negative(Decimal.subtract(b, a))
    case order:
      compact(Decimal.subtract(a, b))

def difference(+a: Decimal.Decimal, +b: Decimal.Decimal) -> Value:
  difference_pick(Decimal.compare(a, b), a, b)

# Error precedence stays deterministic even when operands run concurrently.
def add_values(a: Value, b: Value) -> Value:
  match a b:
    case NegativeNumber{x} NegativeNumber{y}:
      negative(Decimal.add(x, y))
    case NegativeNumber{x} Number{y}:
      difference(Decimal.from_nat(y), x)
    case Number{x} NegativeNumber{y}:
      difference(Decimal.from_nat(x), y)
    case NegativeNumber{x} DecimalNumber{y}:
      difference(y, x)
    case DecimalNumber{x} NegativeNumber{y}:
      difference(x, y)
    case DecimalNumber{x} DecimalNumber{y}:
      DecimalNumber{Decimal.add(x, y)}
    case DecimalNumber{x} Number{y}:
      DecimalNumber{Decimal.add(x, Decimal.from_nat(y))}
    case Number{x} DecimalNumber{y}:
      DecimalNumber{Decimal.add(Decimal.from_nat(x), y)}
    case Number{x} Number{y}:
      compact(Decimal.add(Decimal.from_nat(x), Decimal.from_nat(y)))
    case Failure{e} b:
      Failure{e}
    case a Failure{e}:
      Failure{e}
    case a b:
      Failure{"Expected numbers"}

def add(a: Value, b: Value) -> Value:
  match a:
    case Failure{e}:
      Failure{e}
    case a:
      add_values(a, b)

def multiply(a: Value, b: Value) -> Value:
  match a b:
    case NegativeNumber{x} NegativeNumber{y}:
      compact(Decimal.multiply(x, y))
    case NegativeNumber{x} Number{y}:
      negative(Decimal.multiply(x, Decimal.from_nat(y)))
    case Number{x} NegativeNumber{y}:
      negative(Decimal.multiply(Decimal.from_nat(x), y))
    case NegativeNumber{x} DecimalNumber{y}:
      negative(Decimal.multiply(x, y))
    case DecimalNumber{x} NegativeNumber{y}:
      negative(Decimal.multiply(x, y))
    case DecimalNumber{x} DecimalNumber{y}:
      DecimalNumber{Decimal.multiply(x, y)}
    case DecimalNumber{x} Number{y}:
      DecimalNumber{Decimal.multiply(x, Decimal.from_nat(y))}
    case Number{x} DecimalNumber{y}:
      DecimalNumber{Decimal.multiply(Decimal.from_nat(x), y)}
    case Number{x} Number{y}:
      compact(Decimal.multiply(Decimal.from_nat(x), Decimal.from_nat(y)))
    case Failure{e} b:
      Failure{e}
    case a Failure{e}:
      Failure{e}
    case a b:
      Failure{"Expected numbers"}

def negate(value: Value) -> Value:
  match value:
    case Number{n}:
      negative(Decimal.from_nat(n))
    case DecimalNumber{n}:
      negative(n)
    case NegativeNumber{n}:
      compact(n)
    case Failure{e}:
      Failure{e}
    case value:
      Failure{"Expected numbers"}

def subtract(a: Value, b: Value) -> Value:
  add(a, negate(b))

# Branches are closures so the unselected branch is never evaluated.
def choose(c: Value, yes: Unit -> Value, no: Unit -> Value) -> Value:
  match c:
    case Logical{True{}}:
      yes(Unit{})
    case Logical{False{}}:
      no(Unit{})
    case Failure{e}:
      Failure{e}
    case NegativeNumber{n}:
      Failure{"Expected logical condition"}
    case DecimalNumber{n}:
      Failure{"Expected logical condition"}
    case Number{n}:
      Failure{"Expected logical condition"}

def logical_not(v: Value) -> Value:
  match v:
    case Logical{b}:
      Logical{Bool.not(b)}
    case Failure{e}:
      Failure{e}
    case v:
      Failure{"Expected logical operand"}

type Binding is Data:
  Bound{name: String, value: Value}

def normalize(sensitive: Bool, name: String) -> String:
  match sensitive:
    case True{}:
      name
    case False{}:
      String.to_lower(name)

def found(same: Bool, value: Value, rest: Unit -> Value) -> Value:
  match same:
    case True{}:
      value
    case False{}:
      rest(Unit{})

# First matching binding wins; callers can prepend a transient context.
def lookup(context: List<&2, Binding>, +name: String, +sensitive: Bool) -> Value:
  match context:
    case Nil{}:
      Failure{"Unbound variable: " ++ name}
    case Bound{key, value} <> tail:
      found(String.eq(normalize(sensitive, key), normalize(sensitive, name)), value, u => lookup(tail, name, sensitive))

def round_numeric(value: Value, target: Nat, before: Nat, mode: Decimal.Rounding) -> Value:
  match value:
    case Number{n}:
      compact(Decimal.round(Decimal.from_nat(n), target, before, mode, False{}))
    case DecimalNumber{n}:
      compact(Decimal.round(n, target, before, mode, False{}))
    case NegativeNumber{n}:
      negative(Decimal.round(n, target, before, mode, True{}))
    case Failure{e}:
      Failure{e}
    case value:
      Failure{"Expected numbers"}

def round_direction(negative_places: Bool, count: Nat, value: Value, mode: Decimal.Rounding) -> Value:
  match negative_places:
    case False{}:
      round_numeric(value, count, 0n, mode)
    case True{}:
      round_numeric(value, 0n, count, mode)

def round_precision_fits(fits: Bool, digits: List<&2, U32>, negative_places: Bool, value: Value, mode: Decimal.Rounding) -> Value:
  match fits:
    case True{}:
      round_direction(negative_places, Decimal.coefficient(digits), value, mode)
    case False{}:
      Failure{"Rounding precision exceeds supported index range"}

def round_precision_digits(+digits: List<&2, U32>, negative_places: Bool, value: Value, mode: Decimal.Rounding) -> Value:
  round_precision_fits(Nat.is_le(List.length(&2, U32, digits), 14n), digits, negative_places, value, mode)

def round_precision(places: Decimal.Decimal, negative_places: Bool, value: Value, mode: Decimal.Rounding) -> Value:
  match places:
    case Decimal.Exact{digits, s}:
      round_precision_digits(Decimal.normalize_digits(Decimal.integer_digits(s, digits)), negative_places, value, mode)

def round(value: Value, places: Value, mode: Decimal.Rounding) -> Value:
  match value places:
    case Failure{e} places:
      Failure{e}
    case value Number{n}:
      round_numeric(value, n, 0n, mode)
    case value DecimalNumber{n}:
      round_precision(n, False{}, value, mode)
    case value NegativeNumber{n}:
      round_precision(n, True{}, value, mode)
    case value Failure{e}:
      Failure{e}
    case value places:
      Failure{"Expected numeric rounding precision"}

def evaluate_in(e: Expr, +context: List<&2, Binding>, +sensitive: Bool) -> Value:
  match e:
    case Literal{v}:
      v
    case Variable{name}:
      lookup(context, name, sensitive)
    case Add{a, b}:
      x y = evaluate_in(a, context, sensitive) evaluate_in(b, context, sensitive)
      add(x, y)
    case Multiply{a, b}:
      x y = evaluate_in(a, context, sensitive) evaluate_in(b, context, sensitive)
      multiply(x, y)
    case Round{a, places, mode}:
      x p = evaluate_in(a, context, sensitive) evaluate_in(places, context, sensitive)
      round(x, p, mode)
    case Negate{a}:
      negate(evaluate_in(a, context, sensitive))
    case Subtract{a, b}:
      x y = evaluate_in(a, context, sensitive) evaluate_in(b, context, sensitive)
      subtract(x, y)
    case Not{a}:
      logical_not(evaluate_in(a, context, sensitive))
    case If{c, a, b}:
      choose(evaluate_in(c, context, sensitive), u => evaluate_in(a, context, sensitive), u => evaluate_in(b, context, sensitive))

def evaluate(e: Expr) -> Value:
  evaluate_in(e, Nil{}, False{})

def show(value: Value) -> String:
  match value:
    case Number{n}:
      Nat.show(n)
    case NegativeNumber{n}:
      "-" ++ Decimal.show(n)
    case DecimalNumber{n}:
      Decimal.show(n)
    case Logical{b}:
      Bool.show(b)
    case Failure{e}:
      e
