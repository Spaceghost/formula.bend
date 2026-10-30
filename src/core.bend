import Base
import ./decimal.bend as Decimal

# Small integers use Nat; larger integers and decimals use exact digit lists.
type Value is Data:
  Number{value: Nat}
  DecimalNumber{value: Decimal.Decimal}
  Logical{value: Bool}
  Failure{message: String}

type Expr is Data:
  Literal{value: Value}
  Variable{name: String}
  Add{left: Expr, right: Expr}
  Multiply{left: Expr, right: Expr}
  If{condition: Expr, yes: Expr, no: Expr}
  Not{operand: Expr}

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

# Error precedence stays deterministic even when operands run concurrently.
def add(a: Value, b: Value) -> Value:
  match a b:
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

def multiply(a: Value, b: Value) -> Value:
  match a b:
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

# Branches are closures so the unselected branch is never evaluated.
def choose(c: Value, yes: Unit -> Value, no: Unit -> Value) -> Value:
  match c:
    case Logical{True{}}:
      yes(Unit{})
    case Logical{False{}}:
      no(Unit{})
    case Failure{e}:
      Failure{e}
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
    case DecimalNumber{n}:
      Decimal.show(n)
    case Logical{b}:
      Bool.show(b)
    case Failure{e}:
      e
