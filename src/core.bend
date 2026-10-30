import Base
import ./decimal.bend as Decimal
import ./division.bend as Division
import ./lexer.bend as Lex
import ./string.bend as StringOps

# Small integers use Nat; larger integers and decimals use exact digit lists.
type Value is Data:
  Number{value: Nat}
  IntegerNumber{value: Decimal.Decimal}
  NegativeInteger{value: Decimal.Decimal}
  DecimalNumber{value: Decimal.Decimal}
  NegativeNumber{value: Decimal.Decimal}
  Logical{value: Bool}
  NullValue{}
  TextValue{value: String}
  ArrayNil{}
  ArrayCons{head: Value, tail: Value}
  ArgumentValue{value: Value}
  ArgumentPair{left: Value, right: Value}
  EmptyArgumentValues{}
  Failure{message: String}

type Comparison is Data:
  EqualTo{}
  NotEqualTo{}
  LessThan{}
  LessOrEqual{}
  GreaterThan{}
  GreaterOrEqual{}

type FunctionKind is Data:
  SumFunction{}
  ProductFunction{}
  MinFunction{}
  MaxFunction{}
  AverageFunction{}
  AbsFunction{}
  AndFunction{}
  OrFunction{}
  XorFunction{}
  CountFunction{}
  LeftFunction{}
  RightFunction{}
  MidFunction{}
  LenFunction{}
  FindFunction{}
  SubstituteFunction{}
  ConcatFunction{}
  ContainsFunction{}
  SwitchFunction{}

type ArgumentValidation is Data:
  RawArgument{}
  LogicalArgument{}

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
  And{left: Expr, right: Expr}
  Or{left: Expr, right: Expr}
  Xor{left: Expr, right: Expr}
  PrefixNot{operand: Expr}
  Argument{value: Expr, validation: ArgumentValidation}
  Arguments{left: Expr, right: Expr}
  EmptyArguments{}
  FunctionCall{kind: FunctionKind, arguments: Expr}
  ArrayLiteral{elements: Expr}
  Access{structure: Expr, index: Expr}

def compact_pick(value: Decimal.Decimal, small: Bool) -> Value:
  match value small:
    case Decimal.Exact{digits, 0n} True{}:
      Number{Decimal.coefficient(digits)}
    case Decimal.Exact{digits, 0n} small:
      IntegerNumber{Decimal.Exact{digits, 0n}}
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

def integer_negative_pick(zero: Bool, value: Decimal.Decimal) -> Value:
  match zero:
    case True{}:
      Number{0n}
    case False{}:
      NegativeInteger{value}

def integer_result(value: Value) -> Value:
  match value:
    case DecimalNumber{n}:
      compact(Decimal.canonical(n))
    case NegativeNumber{+n}:
      integer_negative_pick(Decimal.is_zero(n), n)
    case value:
      value

def decimal_result(value: Value) -> Value:
  match value:
    case Number{n}:
      DecimalNumber{Decimal.from_nat(n)}
    case IntegerNumber{n}:
      DecimalNumber{n}
    case NegativeInteger{n}:
      NegativeNumber{n}
    case value:
      value

def numeric_result(integer: Bool, value: Value) -> Value:
  match integer:
    case True{}:
      integer_result(value)
    case False{}:
      decimal_result(value)

def is_integer(value: Value) -> Bool:
  match value:
    case Number{n}:
      True{}
    case IntegerNumber{n}:
      True{}
    case NegativeInteger{n}:
      True{}
    case value:
      False{}

def strip_integer(value: Value) -> Value:
  match value:
    case IntegerNumber{n}:
      DecimalNumber{n}
    case NegativeInteger{n}:
      NegativeNumber{n}
    case value:
      value

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
    case Lex.BigIntegerLiteral{n} <> Nil{}:
      IntegerNumber{n}
    case Lex.DecimalLiteral{n} <> Nil{}:
      DecimalNumber{n}
    case Lex.Minus{} <> Lex.Integer{n} <> Nil{}:
      integer_result(negative(Decimal.from_nat(n)))
    case Lex.Minus{} <> Lex.BigIntegerLiteral{n} <> Nil{}:
      integer_result(negative(n))
    case Lex.Minus{} <> Lex.DecimalLiteral{n} <> Nil{}:
      decimal_result(negative(n))
    case tokens:
      TextValue{original}

def numeric_text_allowed(allowed: Bool, +text: String) -> Value:
  match allowed:
    case True{}:
      numeric_text(Lex.tokenize(text), text)
    case False{}:
      TextValue{text}

def numeric_string_spacing(text: String) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{c, rest}:
      Bool.and(Bool.not(Char.is_space(c)), numeric_string_spacing(rest))

def cast_numeric(value: Value) -> Value:
  match value:
    case TextValue{+text}:
      numeric_text_allowed(numeric_string_spacing(text), text)
    case value:
      value

def ruby_render(value: Value, inspect: Bool, tail_mode: Bool) -> String:
  match value:
    case Number{n}:
      Nat.show(n)
    case IntegerNumber{n}:
      Decimal.show(n)
    case NegativeInteger{n}:
      "-" ++ Decimal.show(n)
    case DecimalNumber{n}:
      Decimal.ruby_show(n, False{})
    case NegativeNumber{n}:
      Decimal.ruby_show(n, True{})
    case TextValue{+s}:
      Bool.pick(String, inspect, StringOps.quote(s), s)
    case Logical{True{}}:
      "true"
    case Logical{False{}}:
      "false"
    case NullValue{}:
      Bool.pick(String, inspect, "nil", "")
    case ArrayNil{}:
      Bool.pick(String, tail_mode, "]", "[]")
    case ArrayCons{head, tail}:
      Bool.pick(String, tail_mode, ", ", "[") ++ ruby_render(head, True{}, False{}) ++ ruby_render(tail, True{}, True{})
    case value:
      "<internal>"

def incompatible_numeric(value: Value) -> Value:
  match value:
    case NullValue{}:
      Failure{"'NilClass' is not coercible to numeric"}
    case Logical{False{}}:
      Failure{"'FalseClass' is not coercible to numeric"}
    case value:
      Failure{"'" ++ ruby_render(value, False{}, False{}) ++ "' is not coercible to numeric"}

def require_numeric_value(value: Value) -> Value:
  match value:
    case IntegerNumber{n}:
      IntegerNumber{n}
    case NegativeInteger{n}:
      NegativeInteger{n}
    case Number{n}:
      Number{n}
    case DecimalNumber{n}:
      DecimalNumber{n}
    case NegativeNumber{n}:
      NegativeNumber{n}
    case Failure{e}:
      Failure{e}
    case value:
      incompatible_numeric(value)

def require_numeric(value: Value) -> Value:
  require_numeric_value(cast_numeric(value))

def array_append(left: Value, right: Value) -> Value:
  match left:
    case ArrayCons{head, tail}:
      ArrayCons{head, array_append(tail, right)}
    case left:
      right

def array_join(left: Value, right: Value) -> Value:
  match right:
    case ArrayNil{}:
      left
    case ArrayCons{head, tail}:
      array_append(left, ArrayCons{head, tail})
    case Failure{e}:
      Failure{e}
    case right:
      Failure{"Expected an array"}

# Ruby array equality does not coerce string elements to numbers. The pinned
# BigDecimal implementation compares equal to integral values in subtraction.
def value_equal(a: Value, b: Value, +strict: Bool) -> Bool:
  match a b:
    case IntegerNumber{x} IntegerNumber{y}:
      Cmp.is_eq(Decimal.compare(x, y))
    case IntegerNumber{x} Number{y}:
      Cmp.is_eq(Decimal.compare(x, Decimal.from_nat(y)))
    case Number{x} IntegerNumber{y}:
      Cmp.is_eq(Decimal.compare(Decimal.from_nat(x), y))
    case IntegerNumber{x} DecimalNumber{y}:
      Cmp.is_eq(Decimal.compare(x, y))
    case DecimalNumber{x} IntegerNumber{y}:
      Cmp.is_eq(Decimal.compare(x, y))
    case NegativeInteger{x} NegativeInteger{y}:
      Cmp.is_eq(Decimal.compare(x, y))
    case NegativeInteger{x} NegativeNumber{y}:
      Cmp.is_eq(Decimal.compare(x, y))
    case NegativeNumber{x} NegativeInteger{y}:
      Cmp.is_eq(Decimal.compare(x, y))
    case ArrayNil{} ArrayNil{}:
      True{}
    case ArrayCons{ah, at} ArrayCons{bh, bt}:
      x y = value_equal(ah, bh, strict) value_equal(at, bt, strict)
      Bool.and(x, y)
    case Number{x} Number{y}:
      Nat.is_eq(x, y)
    case DecimalNumber{x} DecimalNumber{y}:
      Cmp.is_eq(Decimal.compare(x, y))
    case NegativeNumber{x} NegativeNumber{y}:
      Cmp.is_eq(Decimal.compare(x, y))
    case Number{x} DecimalNumber{y}:
      Cmp.is_eq(Decimal.compare(Decimal.from_nat(x), y))
    case DecimalNumber{x} Number{y}:
      Cmp.is_eq(Decimal.compare(x, Decimal.from_nat(y)))
    case TextValue{x} TextValue{y}:
      String.eq(x, y)
    case Logical{x} Logical{y}:
      Cmp.is_eq(Bool.cmp(x, y))
    case NullValue{} NullValue{}:
      True{}
    case a b:
      False{}

def array_contains(array: Value, +candidate: Value) -> Bool:
  match array:
    case ArrayCons{head, tail}:
      Bool.or(value_equal(head, candidate, True{}), array_contains(tail, candidate))
    case array:
      False{}

def array_keep(remove: Bool, head: Value, tail: Value) -> Value:
  match remove:
    case True{}:
      tail
    case False{}:
      ArrayCons{head, tail}

def array_difference(left: Value, +right: Value) -> Value:
  match left:
    case ArrayCons{+head, tail}:
      array_keep(array_contains(right, head), head, array_difference(tail, right))
    case left:
      ArrayNil{}

def array_subtract(left: Value, right: Value) -> Value:
  match right:
    case ArrayNil{}:
      left
    case ArrayCons{head, tail}:
      array_difference(left, ArrayCons{head, tail})
    case Failure{e}:
      Failure{e}
    case right:
      Failure{"Expected an array"}

def array_repeat(count: Nat, +array: Value) -> Value:
  match count:
    case 0n:
      ArrayNil{}
    case 1n+p:
      array_append(array, array_repeat(p, array))

def array_repeat_fits(fits: Bool, digits: List<&2, U32>, array: Value) -> Value:
  match fits:
    case True{}:
      array_repeat(Decimal.coefficient(digits), array)
    case False{}:
      Failure{"Array repetition exceeds supported index range"}

def array_repeat_digits(negative_count: Bool, +digits: List<&2, U32>, array: Value) -> Value:
  match negative_count:
    case True{}:
      Bool.pick(Value, List.is_empty(&2, U32, digits), ArrayNil{}, Failure{"Negative array repetition count"})
    case False{}:
      array_repeat_fits(Nat.is_le(List.length(&2, U32, digits), 14n), digits, array)

def array_repeat_decimal(value: Decimal.Decimal, negative_count: Bool, array: Value) -> Value:
  match value:
    case Decimal.Exact{digits, scale}:
      array_repeat_digits(negative_count, Decimal.normalize_digits(Decimal.integer_digits(scale, digits)), array)

def array_multiply(array: Value, count: Value) -> Value:
  match count:
    case IntegerNumber{n}:
      array_repeat_decimal(n, False{}, array)
    case NegativeInteger{n}:
      array_repeat_decimal(n, True{}, array)
    case Number{n}:
      array_repeat(n, array)
    case DecimalNumber{n}:
      array_repeat_decimal(n, False{}, array)
    case NegativeNumber{n}:
      array_repeat_decimal(n, True{}, array)
    case Failure{e}:
      Failure{e}
    case count:
      Failure{"Expected numeric repetition count"}

# Error precedence stays deterministic even when operands run concurrently.
def add_values(a: Value, b: Value) -> Value:
  match a b:
    case ArrayNil{} b:
      array_join(ArrayNil{}, b)
    case ArrayCons{head, tail} b:
      array_join(ArrayCons{head, tail}, b)
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

def add_cast(+a: Value, +b: Value) -> Value:
  numeric_result(Bool.and(is_integer(a), is_integer(b)), add_values(strip_integer(a), strip_integer(b)))

def add(a: Value, b: Value) -> Value:
  match a:
    case Failure{e}:
      Failure{e}
    case a:
      add_cast(cast_numeric(a), cast_numeric(b))

def multiply_values(a: Value, b: Value) -> Value:
  match a b:
    case ArrayNil{} b:
      array_multiply(ArrayNil{}, b)
    case ArrayCons{head, tail} b:
      array_multiply(ArrayCons{head, tail}, b)
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

def multiply_cast(+a: Value, +b: Value) -> Value:
  numeric_result(Bool.and(is_integer(a), is_integer(b)), multiply_values(strip_integer(a), strip_integer(b)))

def multiply(a: Value, b: Value) -> Value:
  multiply_cast(cast_numeric(a), cast_numeric(b))

def negate_value(value: Value) -> Value:
  match value:
    case Number{n}:
      integer_result(negative(Decimal.from_nat(n)))
    case IntegerNumber{n}:
      integer_result(negative(n))
    case NegativeInteger{n}:
      compact(n)
    case DecimalNumber{n}:
      decimal_result(negative(n))
    case NegativeNumber{n}:
      DecimalNumber{n}
    case Failure{e}:
      Failure{e}
    case value:
      Failure{"Expected numbers"}

def negate(value: Value) -> Value:
  negate_value(cast_numeric(value))

def subtract(a: Value, b: Value) -> Value:
  match a:
    case ArrayNil{}:
      array_subtract(ArrayNil{}, b)
    case ArrayCons{head, tail}:
      array_subtract(ArrayCons{head, tail}, b)
    case a:
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

def truthy(value: Value) -> Bool:
  match value:
    case NullValue{}:
      False{}
    case Logical{b}:
      b
    case value:
      True{}

def decisive(+is_and: Bool, value: Value) -> Bool:
  Bool.xor(is_and, truthy(value))

def logical_recovered(right: Value, left_error: Value, is_and: Bool) -> Value:
  match right:
    case Failure{e}:
      Failure{e}
    case +right:
      Bool.pick(Value, decisive(is_and, right), right, left_error)

def logical_unbound(unbound: Bool, left_error: Value, is_and: Bool, next: Unit -> Value) -> Value:
  match unbound:
    case True{}:
      logical_recovered(next(Unit{}), left_error, is_and)
    case False{}:
      left_error

def logical_chosen(done: Bool, value: Value, next: Unit -> Value) -> Value:
  match done:
    case True{}:
      value
    case False{}:
      next(Unit{})

def logical_left(value: Value, +is_and: Bool, next: Unit -> Value) -> Value:
  match value:
    case Failure{+e}:
      logical_unbound(String.starts_with(e, "Unbound variable: "), Failure{e}, is_and, next)
    case +value:
      logical_chosen(decisive(is_and, value), value, next)

def strict_logical(value: Value) -> Value:
  match value:
    case Logical{b}:
      Logical{b}
    case NullValue{}:
      Logical{False{}}
    case Failure{e}:
      Failure{e}
    case value:
      Failure{"Incompatible logical operand"}

def xor_values(a: Value, b: Value) -> Value:
  match a b:
    case Logical{x} Logical{y}:
      Logical{Bool.xor(x, y)}
    case Failure{e} b:
      Failure{e}
    case a Failure{e}:
      Failure{e}
    case a b:
      Failure{"Incompatible logical operand"}

def logical_xor(a: Value, b: Value) -> Value:
  xor_values(strict_logical(a), strict_logical(b))

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

def round_numeric(value: Value, +target: Nat, before: Nat, mode: Decimal.Rounding) -> Value:
  match value:
    case Number{n}:
      integer_result(compact(Decimal.round(Decimal.from_nat(n), target, before, mode, False{})))
    case IntegerNumber{n}:
      integer_result(compact(Decimal.round(n, target, before, mode, False{})))
    case NegativeInteger{n}:
      integer_result(negative(Decimal.round(n, target, before, mode, True{})))
    case DecimalNumber{n}:
      numeric_result(Nat.is_eq(target, 0n), compact(Decimal.round(n, target, before, mode, False{})))
    case NegativeNumber{n}:
      numeric_result(Nat.is_eq(target, 0n), negative(Decimal.round(n, target, before, mode, True{})))
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
    case value IntegerNumber{n}:
      round_precision(n, False{}, value, mode)
    case value NegativeInteger{n}:
      round_precision(n, True{}, value, mode)
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
    case IntegerNumber{n}:
      Magnitude{False{}, n}
    case NegativeInteger{n}:
      Magnitude{True{}, n}
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
      decimal_result(negative(value))
    case False{}:
      DecimalNumber{value}

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

def divide_nonzero(zero: Bool, a: NumericOperand, sy: Bool, +y: Decimal.Decimal) -> Value:
  match zero a:
    case True{} a:
      Failure{"Division by zero"}
    case False{} Magnitude{sx, +x}:
      division_result(Division.divide(x, y, Division.ruby_places(x, y)), Bool.xor(sx, sy), Decimal.HalfAway{})
    case False{} InvalidNumeric{e}:
      Failure{e}

def divide_default_operands(a: NumericOperand, b: NumericOperand) -> Value:
  match b:
    case Magnitude{sy, +y}:
      divide_nonzero(Decimal.is_zero(y), a, sy, y)
    case InvalidNumeric{e}:
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
    case ArrayNil{} b:
      equality_only(op, Bool.pick(Cmp, value_equal(ArrayNil{}, b, False{}), EQ{}, LT{}))
    case ArrayCons{head, tail} b:
      equality_only(op, Bool.pick(Cmp, value_equal(ArrayCons{head, tail}, b, False{}), EQ{}, LT{}))
    case a b:
      numeric_comparison(numeric_operand(a), numeric_operand(b), op)

def compare(a: Value, b: Value, op: Comparison) -> Value:
  compare_values(cast_numeric(a), cast_numeric(b), op)

# Arguments are evaluated before the function implementation sees their values.
# XOR validates each argument during collection, as in Dentaku's custom node.
def validate_argument(validation: ArgumentValidation, value: Value) -> Value:
  match validation:
    case RawArgument{}:
      value
    case LogicalArgument{}:
      strict_logical(value)

def next_argument_error(error: Maybe<&2, Value>, next: Unit -> Maybe<&2, Value>) -> Maybe<&2, Value>:
  match error:
    case Some{value}:
      Some{value}
    case None{}:
      next(Unit{})

def first_argument_error(tree: Value) -> Maybe<&2, Value>:
  match tree:
    case ArgumentValue{Failure{e}}:
      Some{Failure{e}}
    case ArgumentValue{value}:
      None{}
    case ArgumentPair{a, b}:
      next_argument_error(first_argument_error(a), u => first_argument_error(b))
    case EmptyArgumentValues{}:
      None{}
    case tree:
      Some{Failure{"Invalid argument tree"}}

def logical_combine(left: Bool, right: Value, kind: FunctionKind) -> Value:
  match right kind:
    case Logical{b} AndFunction{}:
      Logical{Bool.and(left, b)}
    case Logical{b} OrFunction{}:
      Logical{Bool.or(left, b)}
    case Logical{b} XorFunction{}:
      Logical{Bool.xor(left, b)}
    case Failure{e} kind:
      Failure{e}
    case right kind:
      Failure{"Incompatible logical operand"}

def logical_fold_guard(accumulator: Value, kind: FunctionKind, next: Bool -> Value) -> Value:
  match accumulator kind:
    case Failure{e} kind:
      Failure{e}
    case Logical{False{}} AndFunction{}:
      Logical{False{}}
    case Logical{True{}} OrFunction{}:
      Logical{True{}}
    case Logical{b} kind:
      next(b)
    case accumulator kind:
      Failure{"Invalid logical accumulator"}

def logical_arguments(tree: Value, accumulator: Value, +kind: FunctionKind) -> Value:
  match tree:
    case ArgumentValue{value}:
      logical_fold_guard(accumulator, kind, b => logical_combine(b, strict_logical(value), kind))
    case ArgumentPair{a, b}:
      logical_fold_guard(accumulator, kind, value => logical_arguments(b, logical_arguments(a, Logical{value}, kind), kind))
    case EmptyArgumentValues{}:
      accumulator
    case tree:
      Failure{"Invalid argument tree"}

def argument_count(tree: Value) -> Nat:
  match tree:
    case ArgumentValue{value}:
      1n
    case ArgumentPair{a, b}:
      Nat.add(argument_count(a), argument_count(b))
    case tree:
      0n

# Array literals retain nesting; only numeric aggregate functions flatten it.
def array_elements(tree: Value, tail: Value) -> Value:
  match tree:
    case ArgumentValue{value}:
      ArrayCons{value, tail}
    case ArgumentPair{a, b}:
      array_elements(a, array_elements(b, tail))
    case tree:
      tail

def array_checked(error: Maybe<&2, Value>, tree: Value) -> Value:
  match error:
    case Some{value}:
      value
    case None{}:
      array_elements(tree, ArrayNil{})

def array_value(+tree: Value) -> Value:
  array_checked(first_argument_error(tree), tree)

def array_length(value: Value) -> Nat:
  match value:
    case ArrayCons{head, tail}:
      1n+array_length(tail)
    case value:
      0n

def count_single(value: Value) -> Value:
  match value:
    case Failure{e}:
      Failure{e}
    case TextValue{s}:
      Number{String.length(s)}
    case ArrayNil{}:
      Number{0n}
    case ArrayCons{head, tail}:
      Number{1n+array_length(tail)}
    case value:
      Number{1n}

def expression_argument_count(tree: Expr) -> Nat:
  match tree:
    case Argument{value, validation}:
      1n
    case Arguments{a, b}:
      Nat.add(expression_argument_count(a), expression_argument_count(b))
    case tree:
      0n

def array_at(value: Value, index: Nat) -> Value:
  match value index:
    case ArrayCons{head, tail} 0n:
      head
    case ArrayCons{head, tail} 1n+p:
      array_at(tail, p)
    case value index:
      NullValue{}

def string_at(text: String, index: Nat) -> Value:
  match text index:
    case SCon{c, rest} 0n:
      TextValue{SCon{c, SNil{}}}
    case SCon{c, rest} 1n+p:
      string_at(rest, p)
    case SNil{} index:
      NullValue{}

def structure_length(value: Value) -> Nat:
  match value:
    case TextValue{s}:
      String.length(s)
    case value:
      array_length(value)

def structure_at(value: Value, index: Nat) -> Value:
  match value:
    case TextValue{s}:
      string_at(s, index)
    case value:
      array_at(value, index)

# Compare arbitrary precision indexes to the structure length before narrowing.
def access_position(in_range: Bool, value: Value, negative_index: Bool, +digits: List<&2, U32>, +length: Nat) -> Value:
  match in_range:
    case False{}:
      NullValue{}
    case True{}:
      structure_at(value, Bool.pick(Nat, negative_index, Nat.sub(length, Decimal.coefficient(digits)), Decimal.coefficient(digits)))

def access_bounded(fits: Bool, +digits: List<&2, U32>, negative_index: Bool, +value: Value) -> Value:
  match fits:
    case False{}:
      Failure{"Index exceeds Ruby signed long range"}
    case True{}:
      access_position(Bool.not(Cmp.is_gt(Decimal.compare(Decimal.Exact{digits, 0n}, Decimal.from_nat(structure_length(value))))), value, negative_index, digits, structure_length(value))

def access_digits(+digits: List<&2, U32>, +negative_index: Bool, value: Value) -> Value:
  access_bounded(Bool.not(Cmp.is_gt(Decimal.compare(Decimal.Exact{digits, 0n}, Decimal.Exact{Bool.pick(U32, negative_index, 8, 7) <> [0, 8, 5, 7, 7, 4, 5, 8, 6, 3, 0, 2, 7, 3, 3, 2, 2, 9], 0n}))), digits, negative_index, value)

def access_numeric(index: Decimal.Decimal, negative_index: Bool, value: Value) -> Value:
  match index:
    case Decimal.Exact{digits, scale}:
      access_digits(Decimal.normalize_digits(Decimal.integer_digits(scale, digits)), negative_index, value)

def substring_result(found: Bool, text: String) -> Value:
  match found:
    case True{}:
      TextValue{text}
    case False{}:
      NullValue{}

def contains_text(+haystack: String, +needle: String) -> Bool:
  match haystack:
    case SNil{}:
      String.eq(needle, "")
    case SCon{c, rest}:
      Bool.or(String.starts_with(SCon{c, rest}, needle), contains_text(rest, needle))

def access_substring(value: Value, +s: String) -> Value:
  match value:
    case TextValue{text}:
      substring_result(contains_text(text, s), s)
    case value:
      Failure{"Invalid index type"}

def access_index(value: Value, index: Value) -> Value:
  match index:
    case IntegerNumber{n}:
      access_numeric(n, False{}, value)
    case NegativeInteger{n}:
      access_numeric(n, True{}, value)
    case Failure{e}:
      Failure{e}
    case Number{n}:
      structure_at(value, n)
    case DecimalNumber{n}:
      access_numeric(n, False{}, value)
    case NegativeNumber{n}:
      access_numeric(n, True{}, value)
    case TextValue{s}:
      access_substring(value, s)
    case index:
      Failure{"Invalid index type"}

def access_value(value: Value, index: Unit -> Value) -> Value:
  match value:
    case NullValue{}:
      NullValue{}
    case Failure{e}:
      Failure{e}
    case ArrayNil{}:
      access_index(ArrayNil{}, index(Unit{}))
    case ArrayCons{head, tail}:
      access_index(ArrayCons{head, tail}, index(Unit{}))
    case TextValue{s}:
      access_index(TextValue{s}, index(Unit{}))
    case value:
      Failure{"Expected indexable structure"}

def string_count_clamp(within: Bool, digits: List<&2, U32>, limit: Nat) -> Value:
  match within:
    case True{}:
      Number{Decimal.coefficient(digits)}
    case False{}:
      Number{limit}

def string_count_long(fits: Bool, +digits: List<&2, U32>, +limit: Nat) -> Value:
  match fits:
    case False{}:
      Failure{"Index exceeds Ruby signed long range"}
    case True{}:
      string_count_clamp(Bool.not(Cmp.is_gt(Decimal.compare(Decimal.Exact{digits, 0n}, Decimal.from_nat(limit)))), digits, limit)

def string_count_digits(negative: Bool, +digits: List<&2, U32>, limit: Nat) -> Value:
  match negative:
    case True{}:
      Bool.pick(Value, List.is_empty(&2, U32, digits), Number{0n}, Failure{"Negative string index"})
    case False{}:
      string_count_long(Bool.not(Cmp.is_gt(Decimal.compare(Decimal.Exact{digits, 0n}, Decimal.Exact{[7, 0, 8, 5, 7, 7, 4, 5, 8, 6, 3, 0, 2, 7, 3, 3, 2, 2, 9], 0n}))), digits, limit)

def string_count_operand(operand: NumericOperand, limit: Nat) -> Value:
  match operand:
    case Magnitude{negative_index, Decimal.Exact{digits, scale}}:
      string_count_digits(negative_index, Decimal.normalize_digits(Decimal.integer_digits(scale, digits)), limit)
    case InvalidNumeric{message}:
      Failure{message}

def string_count(value: Value, limit: Nat) -> Value:
  string_count_operand(numeric_operand(require_numeric(value)), limit)

def named_string_count(count: Value, name: String, argument: String) -> Value:
  match count:
    case Failure{+message}:
      Failure{Bool.pick(String, String.eq(message, "Negative string index"), name ++ "() requires " ++ argument ++ " to be positive", message)}
    case count:
      count

def slice_count(count: Value, +text: String, right: Bool) -> Value:
  match count:
    case Number{+n}:
      TextValue{Bool.pick(String, right, StringOps.drop(text, Nat.sub(String.length(text), n)), StringOps.take(n, text))}
    case Failure{message}:
      Failure{message}
    case count:
      Failure{"Invalid string count"}

def slice_string(value: Value, length: Value, +right: Bool) -> Value:
  +text = ruby_render(value, False{}, False{})
  slice_count(named_string_count(string_count(length, String.length(text)), Bool.pick(String, right, "RIGHT", "LEFT"), "length"), text, right)

def mid_length(length: Value, +text: String, +offset: Nat) -> Value:
  match length:
    case Number{n}:
      TextValue{StringOps.take(n, StringOps.drop(text, Bool.pick(Nat, Nat.is_eq(offset, 0n), Nat.sub(String.length(text), 1n), Nat.sub(offset, 1n))))}
    case Failure{message}:
      Failure{message}
    case length:
      Failure{"Invalid string length"}

def mid_offset(offset: Value, +text: String, length: Unit -> Value) -> Value:
  match offset:
    case Number{n}:
      mid_length(named_string_count(string_count(length(Unit{}), String.length(text)), "MID", "length"), text, n)
    case Failure{message}:
      Failure{message}
    case offset:
      Failure{"Invalid string offset"}

def mid_text(value: Value, offset: Unit -> Value, length: Unit -> Value) -> Value:
  match value:
    case Failure{message}:
      Failure{message}
    case value:
      +text = ruby_render(value, False{}, False{})
      mid_offset(named_string_count(string_count(offset(Unit{}), 1n+String.length(text)), "MID", "offset"), text, length)

def contains_needle(needle: Value, haystack: String) -> Value:
  match needle:
    case Failure{message}:
      Failure{message}
    case needle:
      Logical{contains_text(haystack, ruby_render(needle, False{}, False{}))}

def contains_haystack(haystack: Value, needle: Unit -> Value) -> Value:
  match haystack:
    case Failure{message}:
      Failure{message}
    case haystack:
      contains_needle(needle(Unit{}), ruby_render(haystack, False{}, False{}))

def find_value(position: Maybe<&2, Nat>) -> Value:
  match position:
    case Some{n}:
      Number{n}
    case None{}:
      NullValue{}

def concat_tree(tree: Value) -> String:
  match tree:
    case ArgumentValue{value}:
      ruby_render(value, False{}, False{})
    case ArgumentPair{a, b}:
      x y = concat_tree(a) concat_tree(b)
      x ++ y
    case tree:
      ""

def string_arguments(kind: FunctionKind, values: Value) -> Value:
  match kind values:
    case LenFunction{} ArrayCons{value, ArrayNil{}}:
      Number{String.length(ruby_render(value, False{}, False{}))}
    case LeftFunction{} ArrayCons{value, ArrayCons{count, ArrayNil{}}}:
      slice_string(value, count, False{})
    case RightFunction{} ArrayCons{value, ArrayCons{count, ArrayNil{}}}:
      slice_string(value, count, True{})
    case FindFunction{} ArrayCons{needle, ArrayCons{haystack, ArrayNil{}}}:
      find_value(StringOps.find(ruby_render(haystack, False{}, False{}), ruby_render(needle, False{}, False{}), 1n))
    case SubstituteFunction{} ArrayCons{original, ArrayCons{search, ArrayCons{replacement, ArrayNil{}}}}:
      TextValue{StringOps.substitute(ruby_render(original, False{}, False{}), ruby_render(search, False{}, False{}), ruby_render(replacement, False{}, False{}), "")}
    case ContainsFunction{} ArrayCons{needle, ArrayCons{haystack, ArrayNil{}}}:
      contains_needle(needle, ruby_render(haystack, False{}, False{}))
    case MidFunction{} ArrayCons{value, ArrayCons{offset, ArrayCons{length, ArrayNil{}}}}:
      mid_text(value, u => offset, u => length)
    case kind values:
      Failure{"Invalid string function arguments"}

def switch_pick(equal: Bool, value: Value, next: Unit -> Value) -> Value:
  match equal:
    case True{}:
      value
    case False{}:
      next(Unit{})

def switch_pairs(pairs: Value, +target: Value) -> Value:
  match pairs:
    case ArrayCons{key, ArrayCons{value, rest}}:
      switch_pick(value_equal(target, key, False{}), value, u => switch_pairs(rest, target))
    case ArrayCons{value, ArrayNil{}}:
      value
    case pairs:
      NullValue{}

def switch_values(values: Value) -> Value:
  match values:
    case ArrayCons{target, pairs}:
      switch_pairs(pairs, target)
    case values:
      NullValue{}

def extreme_pick(order: Value, a: Value, b: Value) -> Value:
  match order:
    case Logical{True{}}:
      a
    case Logical{False{}}:
      b
    case Failure{e}:
      Failure{e}
    case order:
      Failure{"Invalid numeric comparison"}

def extreme_compare(is_min: Bool, +a: Value, +b: Value) -> Value:
  match is_min:
    case True{}:
      extreme_pick(compare(a, b, LessOrEqual{}), a, b)
    case False{}:
      extreme_pick(compare(a, b, GreaterOrEqual{}), a, b)

def extreme_value(accumulator: Value, candidate: Value, is_min: Bool) -> Value:
  match accumulator candidate:
    case Failure{e} candidate:
      Failure{e}
    case accumulator Failure{e}:
      Failure{e}
    case NullValue{} candidate:
      candidate
    case accumulator NullValue{}:
      accumulator
    case accumulator candidate:
      extreme_compare(is_min, accumulator, candidate)

def abs_value(value: Value) -> Value:
  match value:
    case NegativeInteger{n}:
      compact(n)
    case NegativeNumber{n}:
      DecimalNumber{n}
    case value:
      require_numeric(value)

def abs_argument(tree: Value) -> Value:
  match tree:
    case ArgumentValue{value}:
      abs_value(cast_numeric(value))
    case tree:
      Failure{"ABS expects one argument"}

def sum_tree(tree: Value) -> Value:
  match tree:
    case ArgumentValue{value}:
      sum_tree(value)
    case ArrayNil{}:
      Number{0n}
    case ArrayCons{head, tail}:
      x y = sum_tree(head) sum_tree(tail)
      add(x, y)
    case ArgumentPair{a, b}:
      x y = sum_tree(a) sum_tree(b)
      add(x, y)
    case EmptyArgumentValues{}:
      Number{0n}
    case tree:
      require_numeric(tree)

def product_tree(tree: Value) -> Value:
  match tree:
    case ArgumentValue{value}:
      product_tree(value)
    case ArrayNil{}:
      Number{1n}
    case ArrayCons{head, tail}:
      x y = product_tree(head) product_tree(tail)
      multiply(x, y)
    case ArgumentPair{a, b}:
      x y = product_tree(a) product_tree(b)
      multiply(x, y)
    case EmptyArgumentValues{}:
      Number{1n}
    case tree:
      require_numeric(tree)

def extreme_tree(tree: Value, +is_min: Bool) -> Value:
  match tree:
    case ArgumentValue{value}:
      extreme_tree(value, is_min)
    case ArrayNil{}:
      NullValue{}
    case ArrayCons{head, tail}:
      x y = extreme_tree(head, is_min) extreme_tree(tail, is_min)
      extreme_value(x, y, is_min)
    case ArgumentPair{a, b}:
      x y = extreme_tree(a, is_min) extreme_tree(b, is_min)
      extreme_value(x, y, is_min)
    case EmptyArgumentValues{}:
      NullValue{}
    case tree:
      require_numeric(tree)

def flattened_count(tree: Value) -> Nat:
  match tree:
    case ArgumentValue{value}:
      flattened_count(value)
    case ArgumentPair{a, b}:
      Nat.add(flattened_count(a), flattened_count(b))
    case ArrayCons{a, b}:
      Nat.add(flattened_count(a), flattened_count(b))
    case ArrayNil{}:
      0n
    case EmptyArgumentValues{}:
      0n
    case tree:
      1n

def average_tree(count: Nat, tree: Value) -> Value:
  match count:
    case 0n:
      Failure{"AVG expects at least one value"}
    case 1n+p:
      divide(sum_tree(tree), Number{1n+p})

def function_arguments(kind: FunctionKind, tree: Value) -> Value:
  match kind:
    case LeftFunction{}:
      string_arguments(LeftFunction{}, array_elements(tree, ArrayNil{}))
    case RightFunction{}:
      string_arguments(RightFunction{}, array_elements(tree, ArrayNil{}))
    case MidFunction{}:
      string_arguments(MidFunction{}, array_elements(tree, ArrayNil{}))
    case LenFunction{}:
      string_arguments(LenFunction{}, array_elements(tree, ArrayNil{}))
    case FindFunction{}:
      string_arguments(FindFunction{}, array_elements(tree, ArrayNil{}))
    case SubstituteFunction{}:
      string_arguments(SubstituteFunction{}, array_elements(tree, ArrayNil{}))
    case ContainsFunction{}:
      string_arguments(ContainsFunction{}, array_elements(tree, ArrayNil{}))
    case ConcatFunction{}:
      TextValue{concat_tree(tree)}
    case SwitchFunction{}:
      switch_values(array_elements(tree, ArrayNil{}))
    case ProductFunction{}:
      product_tree(tree)
    case MinFunction{}:
      extreme_tree(tree, True{})
    case MaxFunction{}:
      extreme_tree(tree, False{})
    case AverageFunction{}:
      +arguments = tree
      average_tree(flattened_count(arguments), arguments)
    case CountFunction{}:
      Number{argument_count(tree)}
    case AbsFunction{}:
      abs_argument(tree)
    case SumFunction{}:
      sum_tree(tree)
    case AndFunction{}:
      logical_arguments(tree, Logical{True{}}, AndFunction{})
    case OrFunction{}:
      logical_arguments(tree, Logical{False{}}, OrFunction{})
    case XorFunction{}:
      logical_arguments(tree, Logical{False{}}, XorFunction{})

def checked_arguments(error: Maybe<&2, Value>, kind: FunctionKind, tree: Value) -> Value:
  match error:
    case Some{value}:
      value
    case None{}:
      function_arguments(kind, tree)

def call(kind: FunctionKind, tree: Value) -> Value:
  match kind tree:
    case SwitchFunction{} EmptyArgumentValues{}:
      NullValue{}
    case MinFunction{} EmptyArgumentValues{}:
      NullValue{}
    case MaxFunction{} EmptyArgumentValues{}:
      NullValue{}
    case kind EmptyArgumentValues{}:
      Failure{"Function expects at least one argument"}
    case kind +tree:
      checked_arguments(first_argument_error(tree), kind, tree)

def evaluate_in(e: Expr, +context: List<&2, Binding>, +sensitive: Bool) -> Value:
  match e:
    case FunctionCall{MidFunction{}, Arguments{Arguments{Argument{value, vv}, Argument{offset, ov}}, Argument{length, lv}}}:
      mid_text(evaluate_in(value, context, sensitive), u => evaluate_in(offset, context, sensitive), u => evaluate_in(length, context, sensitive))
    case FunctionCall{ContainsFunction{}, Arguments{Argument{needle, nv}, Argument{haystack, hv}}}:
      contains_haystack(evaluate_in(haystack, context, sensitive), u => evaluate_in(needle, context, sensitive))
    case ArrayLiteral{elements}:
      array_value(evaluate_in(elements, context, sensitive))
    case Access{structure, index}:
      access_value(evaluate_in(structure, context, sensitive), u => evaluate_in(index, context, sensitive))
    case FunctionCall{CountFunction{}, Argument{a, validation}}:
      count_single(evaluate_in(a, context, sensitive))
    case FunctionCall{CountFunction{}, arguments}:
      Number{expression_argument_count(arguments)}
    case EmptyArguments{}:
      EmptyArgumentValues{}
    case Argument{a, validation}:
      ArgumentValue{validate_argument(validation, evaluate_in(a, context, sensitive))}
    case Arguments{a, b}:
      x y = evaluate_in(a, context, sensitive) evaluate_in(b, context, sensitive)
      ArgumentPair{x, y}
    case FunctionCall{kind, arguments}:
      call(kind, evaluate_in(arguments, context, sensitive))
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
    case And{a, b}:
      logical_left(evaluate_in(a, context, sensitive), True{}, u => evaluate_in(b, context, sensitive))
    case Or{a, b}:
      logical_left(evaluate_in(a, context, sensitive), False{}, u => evaluate_in(b, context, sensitive))
    case Xor{a, b}:
      x y = evaluate_in(a, context, sensitive) evaluate_in(b, context, sensitive)
      logical_xor(x, y)
    case PrefixNot{a}:
      logical_not(evaluate_in(a, context, sensitive))
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
    case IntegerNumber{n}:
      Decimal.show(n)
    case NegativeInteger{n}:
      "-" ++ Decimal.show(n)
    case ArrayNil{}:
      "{}"
    case ArrayCons{head, tail}:
      "{" ++ show(head) ++ ", " ++ show(tail) ++ "}"
    case ArgumentValue{value}:
      "Internal argument value"
    case ArgumentPair{a, b}:
      "Internal argument pair"
    case EmptyArgumentValues{}:
      "Internal empty arguments"
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
def failure_snapshot(+message: String) -> String:
  Bool.pick(String, String.starts_with(message, "Unbound variable: "), "error:Dentaku::UnboundVariableError", Bool.pick(String, String.eq(message, "Division by zero"), "error:Dentaku::ZeroDivisionError", Bool.pick(String, String.eq(message, "Index exceeds Ruby signed long range"), "error:RangeError", "error:Dentaku::ArgumentError")))

def snapshot_render(value: Value, +tail_mode: Bool) -> String:
  match value:
    case IntegerNumber{n}:
      "number:" ++ Decimal.show(Decimal.canonical(n))
    case NegativeInteger{n}:
      "number:-" ++ Decimal.show(Decimal.canonical(n))
    case ArrayNil{}:
      Bool.pick(String, tail_mode, "]", "array:[]")
    case ArrayCons{head, tail}:
      +part = snapshot_render(head, False{})
      Bool.pick(String, tail_mode, "", "array:[") ++ Nat.show(String.length(part)) ++ ":" ++ part ++ snapshot_render(tail, True{})
    case ArgumentValue{value}:
      "internal:argument"
    case ArgumentPair{a, b}:
      "internal:arguments"
    case EmptyArgumentValues{}:
      "internal:empty-arguments"
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
      failure_snapshot(e)

def snapshot(value: Value) -> String:
  snapshot_render(value, False{})

def class_snapshot(value: Value) -> String:
  match value:
    case Number{n}:
      "class:Integer"
    case IntegerNumber{n}:
      "class:Integer"
    case NegativeInteger{n}:
      "class:Integer"
    case DecimalNumber{n}:
      "class:BigDecimal"
    case NegativeNumber{n}:
      "class:BigDecimal"
    case TextValue{s}:
      "class:String"
    case Logical{True{}}:
      "class:TrueClass"
    case Logical{False{}}:
      "class:FalseClass"
    case NullValue{}:
      "class:NilClass"
    case ArrayNil{}:
      "class:Array"
    case ArrayCons{head, tail}:
      "class:Array"
    case Failure{e}:
      failure_snapshot(e)
    case value:
      "internal:class"

def message_snapshot(value: Value) -> String:
  match value:
    case Failure{message}:
      "message:" ++ message
    case value:
      "no-error"
