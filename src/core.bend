import Base
import ./decimal.bend as Decimal
import ./division.bend as Division
import ./lexer.bend as Lex

# Small integers use Nat; larger integers and decimals use exact digit lists.
type Value is Data:
  Number{value: Nat}
  DecimalNumber{value: Decimal.Decimal}
  NegativeNumber{value: Decimal.Decimal}
  Logical{value: Bool}
  NullValue{}
  TextValue{value: String}
  Failure{message: String}

type Comparison is Data:
  EqualTo{}
  NotEqualTo{}
  LessThan{}
  LessOrEqual{}
  GreaterThan{}
  GreaterOrEqual{}

type Expr is Data:
  Literal{value: Value}
  Variable{name: String}
  Add{left: Expr, right: Expr}
  Multiply{left: Expr, right: Expr}
  Divide{left: Expr, right: Expr}
  If{condition: Expr, yes: Expr, no: Expr}
  Not{operand: Expr}
  Negate{operand: Expr}
  Subtract{left: Expr, right: Expr}
  Round{operand: Expr, places: Expr, mode: Decimal.Rounding}
  Compare{operation: Comparison, left: Expr, right: Expr}
  CoerceNumber{operand: Expr}

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

def numeric_text(tokens: List<&2, Lex.Token>, original: String) -> Value:
  match tokens:
    case Lex.Integer{n} <> Nil{}:
      Number{n}
    case Lex.DecimalLiteral{n} <> Nil{}:
      DecimalNumber{n}
    case Lex.Minus{} <> Lex.Integer{n} <> Nil{}:
      negative(Decimal.from_nat(n))
    case Lex.Minus{} <> Lex.DecimalLiteral{n} <> Nil{}:
      negative(n)
    case tokens:
      TextValue{original}

def numeric_text_allowed(allowed: Bool, +text: String) -> Value:
  match allowed:
    case True{}:
      numeric_text(Lex.tokenize(text), text)
    case False{}:
      TextValue{text}

def cast_numeric(value: Value) -> Value:
  match value:
    case TextValue{+text}:
      numeric_text_allowed(String.eq(String.trim(text), text), text)
    case value:
      value

def require_numeric_value(value: Value) -> Value:
  match value:
    case Number{n}:
      Number{n}
    case DecimalNumber{n}:
      DecimalNumber{n}
    case NegativeNumber{n}:
      NegativeNumber{n}
    case Failure{e}:
      Failure{e}
    case value:
      Failure{"Expected numbers"}

def require_numeric(value: Value) -> Value:
  require_numeric_value(cast_numeric(value))

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
      add_values(cast_numeric(a), cast_numeric(b))

def multiply_values(a: Value, b: Value) -> Value:
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

def multiply(a: Value, b: Value) -> Value:
  multiply_values(cast_numeric(a), cast_numeric(b))

def negate_value(value: Value) -> Value:
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

def negate(value: Value) -> Value:
  negate_value(cast_numeric(value))

def subtract(a: Value, b: Value) -> Value:
  add(a, negate(b))

# Branches are closures so the unselected branch is never evaluated.
# Ruby truthiness: only false and null select the false branch.
def choose(c: Value, yes: Unit -> Value, no: Unit -> Value) -> Value:
  match c:
    case Logical{False{}}:
      no(Unit{})
    case NullValue{}:
      no(Unit{})
    case Failure{e}:
      Failure{e}
    case c:
      yes(Unit{})

def logical_not(v: Value) -> Value:
  match v:
    case Logical{b}:
      Logical{Bool.not(b)}
    case Failure{e}:
      Failure{e}
    case NullValue{}:
      Logical{True{}}
    case v:
      Logical{False{}}

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

def round_values(value: Value, places: Value, mode: Decimal.Rounding) -> Value:
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


def round(value: Value, places: Value, mode: Decimal.Rounding) -> Value:
  round_values(cast_numeric(value), cast_numeric(places), mode)

type NumericOperand is Data:
  Magnitude{negative: Bool, value: Decimal.Decimal}
  InvalidNumeric{message: String}

def numeric_operand_value(value: Value) -> NumericOperand:
  match value:
    case Number{n}:
      Magnitude{False{}, Decimal.from_nat(n)}
    case DecimalNumber{n}:
      Magnitude{False{}, n}
    case NegativeNumber{n}:
      Magnitude{True{}, n}
    case Failure{e}:
      InvalidNumeric{e}
    case value:
      InvalidNumeric{"Expected numbers"}

def numeric_operand(value: Value) -> NumericOperand:
  numeric_operand_value(cast_numeric(value))

def signed_result(neg: Bool, value: Decimal.Decimal) -> Value:
  match neg:
    case True{}:
      negative(value)
    case False{}:
      compact(value)

def division_result(result: Division.DivisionResult, +neg: Bool, mode: Decimal.Rounding) -> Value:
  match result:
    case Division.DivisionByZero{}:
      Failure{"Division by zero"}
    case Division.Quotient{value, remainder, divisor}:
      signed_result(neg, Decimal.canonical(Division.round_coefficient(value, Division.needs_increment(mode, neg, remainder, divisor))))

def divide_operands(a: NumericOperand, b: NumericOperand, places: Nat, mode: Decimal.Rounding) -> Value:
  match a b:
    case Magnitude{sx, x} Magnitude{sy, y}:
      division_result(Division.divide(x, y, places), Bool.xor(sx, sy), mode)
    case InvalidNumeric{e} b:
      Failure{e}
    case a InvalidNumeric{e}:
      Failure{e}

# Explicit decimal places and rounding; callers select their compatibility policy.
def divide_at(a: Value, b: Value, places: Nat, mode: Decimal.Rounding) -> Value:
  divide_operands(numeric_operand(a), numeric_operand(b), places, mode)

def divide_default_operands(a: NumericOperand, b: NumericOperand) -> Value:
  match a b:
    case Magnitude{sx, +x} Magnitude{sy, +y}:
      division_result(Division.divide(x, y, Division.ruby_places(x, y)), Bool.xor(sx, sy), Decimal.HalfAway{})
    case InvalidNumeric{e} b:
      Failure{e}
    case a InvalidNumeric{e}:
      Failure{e}

def divide(a: Value, b: Value) -> Value:
  divide_default_operands(numeric_operand(a), numeric_operand(b))

def incompatible_comparison(op: Comparison) -> Value:
  match op:
    case EqualTo{}:
      Logical{False{}}
    case NotEqualTo{}:
      Logical{True{}}
    case op:
      Failure{"Incompatible comparison operands"}

def apply_order(op: Comparison, +order: Cmp) -> Value:
  match op:
    case EqualTo{}:
      Logical{Cmp.is_eq(order)}
    case NotEqualTo{}:
      Logical{Bool.not(Cmp.is_eq(order))}
    case LessThan{}:
      Logical{Cmp.is_lt(order)}
    case LessOrEqual{}:
      Logical{Bool.not(Cmp.is_gt(order))}
    case GreaterThan{}:
      Logical{Cmp.is_gt(order)}
    case GreaterOrEqual{}:
      Logical{Bool.not(Cmp.is_lt(order))}

def reverse_order(order: Cmp) -> Cmp:
  match order:
    case LT{}:
      GT{}
    case GT{}:
      LT{}
    case EQ{}:
      EQ{}

def signed_order(sa: Bool, a: Decimal.Decimal, sb: Bool, b: Decimal.Decimal) -> Cmp:
  match sa sb:
    case False{} False{}:
      Decimal.compare(a, b)
    case True{} True{}:
      reverse_order(Decimal.compare(a, b))
    case True{} False{}:
      LT{}
    case False{} True{}:
      GT{}

def numeric_comparison(a: NumericOperand, b: NumericOperand, op: Comparison) -> Value:
  match a b:
    case Magnitude{sa, a} Magnitude{sb, b}:
      apply_order(op, signed_order(sa, a, sb, b))
    case a b:
      incompatible_comparison(op)

def equality_only(op: Comparison, order: Cmp) -> Value:
  match op:
    case EqualTo{}:
      apply_order(EqualTo{}, order)
    case NotEqualTo{}:
      apply_order(NotEqualTo{}, order)
    case op:
      Failure{"Incompatible comparison operands"}

def compare_values(a: Value, b: Value, op: Comparison) -> Value:
  match a b:
    case Failure{e} b:
      Failure{e}
    case a Failure{e}:
      Failure{e}
    case TextValue{x} TextValue{y}:
      apply_order(op, String.order(x, y))
    case Logical{x} Logical{y}:
      equality_only(op, Bool.cmp(x, y))
    case NullValue{} NullValue{}:
      equality_only(op, EQ{})
    case a b:
      numeric_comparison(numeric_operand(a), numeric_operand(b), op)

def compare(a: Value, b: Value, op: Comparison) -> Value:
  compare_values(cast_numeric(a), cast_numeric(b), op)

def evaluate_in(e: Expr, +context: List<&2, Binding>, +sensitive: Bool) -> Value:
  match e:
    case Literal{v}:
      v
    case Variable{name}:
      lookup(context, name, sensitive)
    case Add{a, b}:
      x y = evaluate_in(a, context, sensitive) evaluate_in(b, context, sensitive)
      add(x, y)
    case Divide{a, b}:
      x y = evaluate_in(a, context, sensitive) evaluate_in(b, context, sensitive)
      divide(x, y)
    case Multiply{a, b}:
      x y = evaluate_in(a, context, sensitive) evaluate_in(b, context, sensitive)
      multiply(x, y)
    case CoerceNumber{a}:
      require_numeric(evaluate_in(a, context, sensitive))
    case Compare{op, a, b}:
      x y = evaluate_in(a, context, sensitive) evaluate_in(b, context, sensitive)
      compare(x, y, op)
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
    case NullValue{}:
      "null"
    case TextValue{s}:
      s
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

# Typed, canonical snapshots for cross-runtime differential fixtures.
def snapshot(value: Value) -> String:
  match value:
    case Number{n}:
      "number:" ++ Nat.show(n)
    case DecimalNumber{n}:
      "number:" ++ Decimal.show(Decimal.canonical(n))
    case NegativeNumber{n}:
      "number:-" ++ Decimal.show(Decimal.canonical(n))
    case Logical{True{}}:
      "boolean:true"
    case Logical{False{}}:
      "boolean:false"
    case NullValue{}:
      "null"
    case TextValue{s}:
      "string:" ++ s
    case Failure{e}:
      "error:" ++ e
