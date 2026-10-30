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
  SymbolValue{value: String}
  HashNil{}
  HashEntry{key: Value, value: Value, tail: Value}
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

type EnumerationKind is Data:
  MapItems{}
  FilterItems{}
  AllItems{}
  AnyItems{}

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
  CaseExpression{subject: Expr, clauses: Expr}
  WhenExpression{key: Expr, value: Expr, rest: Expr}
  ElseExpression{value: Expr}
  NoCaseMatch{}
  EnumerationExpression{kind: EnumerationKind, collection: Expr, binder: String, body: Expr}
  ReductionExpression{collection: Expr, memo_binder: String, item_binder: String, body: Expr, initial: Expr}
  MidExpression{value: Expr, offset: Expr, length: Expr}
  ContainsExpression{needle: Expr, haystack: Expr}
  CountOneExpression{value: Expr}
  CountManyExpression{arguments: Expr, count: Nat}

type EvaluationMode is Data:
  EvaluateOne{}
  EvaluateItems{kind: EnumerationKind, binder: String}
  EvaluateReduction{memo_binder: String, item_binder: String, memo: Value}

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

def has_negative_sign(value: Value) -> Bool:
  match value:
    case NegativeNumber{n}:
      True{}
    case NegativeInteger{n}:
      True{}
    case value:
      False{}

def decimal_zero_sign(negative_zero: Bool, value: Value) -> Value:
  match value:
    case DecimalNumber{+n}:
      Bool.pick(Value, Bool.and(negative_zero, Decimal.is_zero(n)), NegativeNumber{n}, DecimalNumber{n})
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
      NegativeNumber{n}
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
    case SymbolValue{+s}:
      Bool.pick(String, inspect, ":" ++ s, s)
    case HashNil{}:
      Bool.pick(String, tail_mode, "}", "{}")
    case HashEntry{key, value, tail}:
      Bool.pick(String, tail_mode, ", ", "{") ++ ruby_render(key, True{}, False{}) ++ "=>" ++ ruby_render(value, True{}, False{}) ++ ruby_render(tail, True{}, True{})
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
def hash_key_equal(a: Value, b: Value) -> Bool:
  match a b:
    case TextValue{x} TextValue{y}:
      String.eq(x, y)
    case SymbolValue{x} SymbolValue{y}:
      String.eq(x, y)
    case a b:
      False{}

def hash_find(hash: Value, +key: Value) -> Maybe<&2, Value>:
  match hash:
    case HashEntry{k, value, tail}:
      Bool.pick(Maybe<&2, Value>, hash_key_equal(k, key), Some{value}, hash_find(tail, key))
    case hash:
      None{}

def hash_remove(hash: Value, +key: Value) -> Value:
  match hash:
    case HashEntry{+k, value, +tail}:
      Bool.pick(Value, hash_key_equal(k, key), tail, HashEntry{k, value, hash_remove(tail, key)})
    case hash:
      HashNil{}

def hash_equal_found(found: Maybe<&2, Value>, compare: Value -> Bool) -> Bool:
  match found:
    case Some{value}:
      compare(value)
    case None{}:
      False{}

def hash_get_found(result: Maybe<&2, Value>) -> Value:
  match result:
    case Some{value}:
      value
    case None{}:
      NullValue{}

def with_value(value: Value, next: Value -> Value) -> Value:
  match value:
    case Failure{message}:
      Failure{message}
    case value:
      next(value)

def hash_get(hash: Value, key: Value) -> Value:
  hash_get_found(hash_find(hash, key))

def value_equal(a: Value, b: Value, +strict: Bool) -> Bool:
  match a b:
    case HashNil{} HashNil{}:
      True{}
    case HashEntry{+key, value, tail} +b:
      Bool.and(hash_equal_found(hash_find(b, key), other => value_equal(value, other, strict)), value_equal(tail, hash_remove(b, key), strict))
    case SymbolValue{x} SymbolValue{y}:
      String.eq(x, y)
    case NegativeNumber{x} Number{y}:
      Bool.and(Decimal.is_zero(x), Nat.is_eq(y, 0n))
    case Number{x} NegativeNumber{y}:
      Bool.and(Nat.is_eq(x, 0n), Decimal.is_zero(y))
    case NegativeNumber{x} DecimalNumber{y}:
      Bool.and(Decimal.is_zero(x), Decimal.is_zero(y))
    case DecimalNumber{x} NegativeNumber{y}:
      Bool.and(Decimal.is_zero(x), Decimal.is_zero(y))
    case NegativeNumber{x} IntegerNumber{y}:
      Bool.and(Decimal.is_zero(x), Decimal.is_zero(y))
    case IntegerNumber{x} NegativeNumber{y}:
      Bool.and(Decimal.is_zero(x), Decimal.is_zero(y))
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
  decimal_zero_sign(Bool.and(has_negative_sign(a), has_negative_sign(b)), numeric_result(Bool.and(is_integer(a), is_integer(b)), add_values(strip_integer(a), strip_integer(b))))

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
  decimal_zero_sign(Bool.xor(has_negative_sign(a), has_negative_sign(b)), numeric_result(Bool.and(is_integer(a), is_integer(b)), multiply_values(strip_integer(a), strip_integer(b))))

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
      NegativeNumber{n}
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
  ScopedBound{name: String, value: Value}
  SymbolBound{name: String, value: Value}

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
    case ScopedBound{key, value} <> tail:
      found(String.eq(key, normalize(sensitive, name)), value, u => lookup(tail, name, sensitive))
    case SymbolBound{key, value} <> tail:
      found(String.eq(normalize(sensitive, key), normalize(sensitive, name)), value, u => lookup(tail, name, sensitive))

# Root calculator storage normalizes keys; Enum's FlatHash merge preserves them.
def flatten_fields(value: Value, +prefix: String, +scoped: Bool) -> List<&2, Binding>:
  match value:
    case HashEntry{key, +value, tail}:
      +name = prefix ++ "." ++ ruby_render(key, False{}, False{})
      List.append(&2, Binding, flatten_fields(tail, prefix, scoped), List.append(&2, Binding, flatten_fields(value, name, scoped), [Bool.pick(Binding, scoped, ScopedBound{name, value}, Bound{name, value})]))
    case value:
      Nil{}

def store_context(context: List<&2, Binding>) -> List<&2, Binding>:
  match context:
    case Bound{+name, +value} <> rest:
      List.append(&2, Binding, flatten_fields(value, name, False{}), Bound{name, value} <> store_context(rest))
    case SymbolBound{+name, +value} <> rest:
      List.append(&2, Binding, flatten_fields(value, name, False{}), Bound{name, value} <> store_context(rest))
    case ScopedBound{name, value} <> rest:
      ScopedBound{name, value} <> store_context(rest)
    case Nil{}:
      Nil{}

def item_context(+name: String, +value: Value, context: List<&2, Binding>, sensitive: Bool) -> List<&2, Binding>:
  +key = normalize(sensitive, name)
  ScopedBound{key, value} <> List.append(&2, Binding, flatten_fields(value, key, True{}), context)

def explicit_evaluation_mode(context: List<&2, Binding>) -> Bool:
  match context:
    case SymbolBound{name, value} <> rest:
      Bool.or(String.eq(name, "__evaluation_mode"), explicit_evaluation_mode(rest))
    case head <> rest:
      explicit_evaluation_mode(rest)
    case Nil{}:
      False{}

def evaluation_context(+context: List<&2, Binding>, strict: Bool) -> List<&2, Binding>:
  Bool.pick(List<&2, Binding>, explicit_evaluation_mode(context), context, SymbolBound{"__evaluation_mode", SymbolValue{Bool.pick(String, strict, "strict", "permissive")}} <> context)

def mapped_result(mode: Value, +value: Value) -> Value:
  match mode value:
    case SymbolValue{mode} Failure{message}:
      Bool.pick(Value, String.eq(mode, "strict"), value, NullValue{})
    case mode Failure{message}:
      NullValue{}
    case mode value:
      value

def permissive_result(+value: Value) -> Value:
  match value:
    case Failure{message}:
      Bool.pick(Value, String.eq(message, "Index exceeds Ruby signed long range"), value, NullValue{})
    case value:
      value

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
      decimal_zero_sign(True{}, numeric_result(Nat.is_eq(target, 0n), negative(Decimal.round(n, target, before, mode, True{}))))
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
      NegativeNumber{value}
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

def signed_order_magnitude(sa: Bool, a: Decimal.Decimal, sb: Bool, b: Decimal.Decimal) -> Cmp:
  match sa sb:
    case False{} False{}:
      Decimal.compare(a, b)
    case True{} True{}:
      reverse_order(Decimal.compare(a, b))
    case True{} False{}:
      LT{}
    case False{} True{}:
      GT{}

def signed_order(sa: Bool, +a: Decimal.Decimal, sb: Bool, +b: Decimal.Decimal) -> Cmp:
  signed_order_magnitude(Bool.and(sa, Bool.not(Decimal.is_zero(a))), a, Bool.and(sb, Bool.not(Decimal.is_zero(b))), b)

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
    case HashNil{} b:
      equality_only(op, Bool.pick(Cmp, value_equal(HashNil{}, b, False{}), EQ{}, LT{}))
    case HashEntry{key, value, tail} b:
      equality_only(op, Bool.pick(Cmp, value_equal(HashEntry{key, value, tail}, b, False{}), EQ{}, LT{}))
    case SymbolValue{x} SymbolValue{y}:
      apply_order(op, String.order(x, y))
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

def hash_length(value: Value) -> Nat:
  match value:
    case HashEntry{key, item, tail}:
      1n+hash_length(tail)
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
    case HashNil{}:
      Number{0n}
    case HashEntry{key, value, tail}:
      Number{1n+hash_length(tail)}
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
  access_bounded(Bool.not(Cmp.is_gt(Decimal.compare(Decimal.Exact{digits, 0n}, Decimal.Exact{Bool.pick(U32, negative_index, 8, 7) <> [0, 8, 5, 7, 7, 4, 5, 8, 6, 3, 0, 2, 7, 3, 3, 2, 2, 9], 0n}))), digits, Bool.and(negative_index, Bool.not(Decimal.is_zero_digits(digits))), value)

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
    case HashNil{}:
      with_value(index(Unit{}), key => hash_get(HashNil{}, key))
    case HashEntry{key, item, tail}:
      with_value(index(Unit{}), at => hash_get(HashEntry{key, item, tail}, at))
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

def collection_nodes(value: Value) -> List<&2, Value>:
  match value:
    case NullValue{}:
      Nil{}
    case ArrayNil{}:
      Nil{}
    case ArrayCons{head, tail}:
      ArgumentValue{head} <> collection_nodes(tail)
    case HashNil{}:
      Nil{}
    case HashEntry{key, item, tail}:
      ArgumentValue{ArrayCons{key, ArrayCons{item, ArrayNil{}}}} <> collection_nodes(tail)
    case value:
      [ArgumentValue{value}]

def prepend_batch_split(head: Value, result: List<&2, Value> & List<&2, Value>) -> List<&2, Value> & List<&2, Value>:
  (left, right) = result
  (head <> left, right)

def split_batch_nodes(count: Nat, nodes: List<&2, Value>) -> List<&2, Value> & List<&2, Value>:
  match count nodes:
    case 0n nodes:
      (Nil{}, nodes)
    case 1n+p Nil{}:
      (Nil{}, Nil{})
    case 1n+p head <> rest:
      prepend_batch_split(head, split_batch_nodes(p, rest))

def parallel_batch_split(parts: List<&2, Value> & List<&2, Value>, left: List<&2, Value> -> Value, right: List<&2, Value> -> Value) -> Value:
  (a, b) = parts
  x y = left(a) right(b)
  ArgumentPair{x, y}

def balance_batch(fuel: Nat, count: Nat, nodes: List<&2, Value>) -> Value:
  match fuel count nodes:
    case fuel 0n nodes:
      EmptyArgumentValues{}
    case fuel 1n node <> Nil{}:
      node
    case 0n count nodes:
      Failure{"Internal batch balancing limit"}
    case 1n+ +p +count nodes:
      +half = Nat.div(count, 2n)
      parallel_batch_split(split_batch_nodes(half, nodes), left => balance_batch(p, half, left), right => balance_batch(p, Nat.sub(count, half), right))

def balanced_nodes(+nodes: List<&2, Value>) -> Value:
  +size = List.length(&2, Value, nodes)
  balance_batch(size, size, nodes)

def collection_batch(value: Value) -> Value:
  balanced_nodes(collection_nodes(value))

def numeric_nodes(tree: Value) -> List<&2, Value>:
  match tree:
    case ArgumentValue{value}:
      numeric_nodes(value)
    case ArgumentPair{a, b}:
      List.append(&2, Value, numeric_nodes(a), numeric_nodes(b))
    case ArrayCons{head, tail}:
      List.append(&2, Value, numeric_nodes(head), numeric_nodes(tail))
    case ArrayNil{}:
      Nil{}
    case EmptyArgumentValues{}:
      Nil{}
    case tree:
      [ArgumentValue{tree}]

def numeric_batch(tree: Value) -> Value:
  balanced_nodes(numeric_nodes(tree))

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
      divide(add(Number{0n}, sum_tree(tree)), Number{1n+p})

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
      product_tree(numeric_batch(tree))
    case MinFunction{}:
      extreme_tree(numeric_batch(tree), True{})
    case MaxFunction{}:
      extreme_tree(numeric_batch(tree), False{})
    case AverageFunction{}:
      +arguments = numeric_batch(tree)
      average_tree(argument_count(arguments), arguments)
    case CountFunction{}:
      Number{argument_count(tree)}
    case AbsFunction{}:
      abs_argument(tree)
    case SumFunction{}:
      add(Number{0n}, sum_tree(numeric_batch(tree)))
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

def case_subject(subjects: List<&2, Value>) -> Value:
  match subjects:
    case head <> tail:
      head
    case Nil{}:
      Failure{"Missing CASE subject"}

def with_case_value(value: Value, next: Value -> Value) -> Value:
  match value:
    case Failure{message}:
      Failure{message}
    case value:
      next(value)

def case_when_value(key: Value, subject: Value, yes: Unit -> Value, no: Unit -> Value) -> Value:
  match key:
    case Failure{message}:
      Failure{message}
    case key:
      choose(Logical{value_equal(key, subject, False{})}, yes, no)

# CASE subjects use an internal value stack, separate from user bindings.
# Every recursive evaluation still consumes a structural subexpression.
def argument_expressions(tree: Expr) -> List<&2, Expr>:
  match tree:
    case Argument{value, validation}:
      [value]
    case Arguments{a, b}:
      List.append(&2, Expr, argument_expressions(a), argument_expressions(b))
    case tree:
      Nil{}

def prepare_mid(arguments: List<&2, Expr>, fallback: Expr) -> Expr:
  match arguments:
    case value <> offset <> length <> Nil{}:
      MidExpression{value, offset, length}
    case arguments:
      fallback

def prepare_contains(arguments: List<&2, Expr>, fallback: Expr) -> Expr:
  match arguments:
    case needle <> haystack <> Nil{}:
      ContainsExpression{needle, haystack}
    case arguments:
      fallback

def prepare_count(arguments: List<&2, Expr>, tree: Expr) -> Expr:
  match arguments:
    case value <> Nil{}:
      CountOneExpression{value}
    case arguments:
      CountManyExpression{tree, List.length(&2, Expr, arguments)}

def prepare_call(kind: FunctionKind, +arguments: Expr) -> Expr:
  match kind:
    case MidFunction{}:
      prepare_mid(argument_expressions(arguments), FunctionCall{MidFunction{}, arguments})
    case ContainsFunction{}:
      prepare_contains(argument_expressions(arguments), FunctionCall{ContainsFunction{}, arguments})
    case CountFunction{}:
      prepare_count(argument_expressions(arguments), arguments)
    case kind:
      FunctionCall{kind, arguments}

# Normalize call evaluation order without executing any expression. Dedicated
# nodes keep the evaluator's batch dispatch independent of argument-tree shape.
def prepare_expression(e: Expr) -> Expr:
  match e:
    case FunctionCall{kind, arguments}:
      prepare_call(kind, prepare_expression(arguments))
    case Literal{value}:
      Literal{value}
    case Variable{name}:
      Variable{name}
    case Add{a, b}:
      Add{prepare_expression(a), prepare_expression(b)}
    case Multiply{a, b}:
      Multiply{prepare_expression(a), prepare_expression(b)}
    case Divide{a, b}:
      Divide{prepare_expression(a), prepare_expression(b)}
    case If{condition, yes, no}:
      If{prepare_expression(condition), prepare_expression(yes), prepare_expression(no)}
    case Not{a}:
      Not{prepare_expression(a)}
    case Negate{a}:
      Negate{prepare_expression(a)}
    case Subtract{a, b}:
      Subtract{prepare_expression(a), prepare_expression(b)}
    case Round{a, places, mode}:
      Round{prepare_expression(a), prepare_expression(places), mode}
    case Compare{operation, a, b}:
      Compare{operation, prepare_expression(a), prepare_expression(b)}
    case CoerceNumber{a}:
      CoerceNumber{prepare_expression(a)}
    case And{a, b}:
      And{prepare_expression(a), prepare_expression(b)}
    case Or{a, b}:
      Or{prepare_expression(a), prepare_expression(b)}
    case Xor{a, b}:
      Xor{prepare_expression(a), prepare_expression(b)}
    case PrefixNot{a}:
      PrefixNot{prepare_expression(a)}
    case Argument{a, validation}:
      Argument{prepare_expression(a), validation}
    case Arguments{a, b}:
      Arguments{prepare_expression(a), prepare_expression(b)}
    case EmptyArguments{}:
      EmptyArguments{}
    case ArrayLiteral{a}:
      ArrayLiteral{prepare_expression(a)}
    case Access{a, index}:
      Access{prepare_expression(a), prepare_expression(index)}
    case CaseExpression{subject, clauses}:
      CaseExpression{prepare_expression(subject), prepare_expression(clauses)}
    case WhenExpression{key, value, rest}:
      WhenExpression{prepare_expression(key), prepare_expression(value), prepare_expression(rest)}
    case ElseExpression{value}:
      ElseExpression{prepare_expression(value)}
    case NoCaseMatch{}:
      NoCaseMatch{}
    case EnumerationExpression{kind, collection, binder, body}:
      EnumerationExpression{kind, prepare_expression(collection), binder, prepare_expression(body)}
    case ReductionExpression{collection, memo_binder, item_binder, body, initial}:
      ReductionExpression{prepare_expression(collection), memo_binder, item_binder, prepare_expression(body), prepare_expression(initial)}
    case MidExpression{value, offset, length}:
      MidExpression{prepare_expression(value), prepare_expression(offset), prepare_expression(length)}
    case ContainsExpression{needle, haystack}:
      ContainsExpression{prepare_expression(needle), prepare_expression(haystack)}
    case CountOneExpression{value}:
      CountOneExpression{prepare_expression(value)}
    case CountManyExpression{arguments, count}:
      CountManyExpression{prepare_expression(arguments), count}

def enumeration_leaf(kind: EnumerationKind, item: Value, mapped: Value) -> Value:
  match kind mapped:
    case MapItems{} mapped:
      ArgumentValue{mapped}
    case kind Failure{message}:
      Failure{message}
    case FilterItems{} mapped:
      Bool.pick(Value, truthy(mapped), ArgumentValue{item}, EmptyArgumentValues{})
    case AllItems{} mapped:
      Logical{truthy(mapped)}
    case AnyItems{} mapped:
      Logical{truthy(mapped)}

def filter_leaf(item: Value, mapped: Value) -> Value:
  match mapped:
    case Failure{message}:
      ArgumentValue{Failure{message}}
    case mapped:
      Bool.pick(Value, truthy(mapped), ArgumentValue{item}, EmptyArgumentValues{})

def enumeration_empty(kind: EnumerationKind) -> Value:
  match kind:
    case AllItems{}:
      Logical{True{}}
    case AnyItems{}:
      Logical{False{}}
    case kind:
      EmptyArgumentValues{}

def enumeration_decide(left: Value, decisive_value: Bool, next: Unit -> Value) -> Value:
  match left:
    case Failure{message}:
      Failure{message}
    case Logical{+b}:
      logical_chosen(Cmp.is_eq(Bool.cmp(b, decisive_value)), Logical{b}, next)
    case left:
      Failure{"Invalid enumeration predicate"}

def enumeration_finish(kind: EnumerationKind, result: Value) -> Value:
  match kind:
    case MapItems{}:
      array_value(result)
    case FilterItems{}:
      array_value(result)
    case kind:
      result

# Recursion is lexicographic over expression and batch. An enum enters its body
# subexpression with a fresh batch; each repeated body evaluation consumes a
# smaller batch node. Context and mode can then change without unsafe recursion.
def evaluate_machine(e: Expr, +batch: Value, +context: List<&2, Binding>, +sensitive: Bool, +subjects: List<&2, Value>, mode: EvaluationMode) -> Value:
  match e batch mode:
    case +e ArgumentPair{a, b} EvaluateItems{AllItems{}, +binder}:
      enumeration_decide(evaluate_machine(e, a, context, sensitive, subjects, EvaluateItems{AllItems{}, binder}), False{}, u => evaluate_machine(e, b, context, sensitive, subjects, EvaluateItems{AllItems{}, binder}))
    case +e ArgumentPair{a, b} EvaluateItems{AnyItems{}, +binder}:
      enumeration_decide(evaluate_machine(e, a, context, sensitive, subjects, EvaluateItems{AnyItems{}, binder}), True{}, u => evaluate_machine(e, b, context, sensitive, subjects, EvaluateItems{AnyItems{}, binder}))
    case +e ArgumentPair{a, b} EvaluateItems{+kind, +binder}:
      x y = evaluate_machine(e, a, context, sensitive, subjects, EvaluateItems{kind, binder}) evaluate_machine(e, b, context, sensitive, subjects, EvaluateItems{kind, binder})
      ArgumentPair{x, y}
    case +e ArgumentValue{+item} EvaluateItems{FilterItems{}, binder}:
      filter_leaf(item, evaluate_machine(e, item, item_context(binder, item, context, sensitive), sensitive, subjects, EvaluateOne{}))
    case +e ArgumentValue{+item} EvaluateItems{kind, binder}:
      enumeration_leaf(kind, item, mapped_result(lookup(context, "__evaluation_mode", sensitive), evaluate_machine(e, item, item_context(binder, item, context, sensitive), sensitive, subjects, EvaluateOne{})))
    case e EmptyArgumentValues{} EvaluateItems{kind, binder}:
      enumeration_empty(kind)
    case +e ArgumentPair{a, b} EvaluateReduction{+memo_binder, +item_binder, memo}:
      with_value(evaluate_machine(e, a, context, sensitive, subjects, EvaluateReduction{memo_binder, item_binder, memo}), next => evaluate_machine(e, b, context, sensitive, subjects, EvaluateReduction{memo_binder, item_binder, next}))
    case +e ArgumentValue{+item} EvaluateReduction{memo_binder, item_binder, memo}:
      evaluate_machine(e, item, item_context(item_binder, item, item_context(memo_binder, memo, context, sensitive), sensitive), sensitive, subjects, EvaluateOne{})
    case e EmptyArgumentValues{} EvaluateReduction{memo_binder, item_binder, memo}:
      memo
    case EnumerationExpression{+kind, collection, binder, body} batch EvaluateOne{}:
      with_value(evaluate_machine(collection, batch, context, sensitive, subjects, EvaluateOne{}), value => enumeration_finish(kind, evaluate_machine(body, collection_batch(value), context, sensitive, subjects, EvaluateItems{kind, binder})))
    case ReductionExpression{collection, memo_binder, item_binder, body, initial} batch EvaluateOne{}:
      with_value(evaluate_machine(collection, batch, context, sensitive, subjects, EvaluateOne{}), values => with_value(evaluate_machine(initial, batch, context, sensitive, subjects, EvaluateOne{}), memo => evaluate_machine(body, collection_batch(values), context, sensitive, subjects, EvaluateReduction{memo_binder, item_binder, memo})))
    case CaseExpression{subject, clauses} batch EvaluateOne{}:
      with_case_value(evaluate_machine(subject, batch, context, sensitive, subjects, EvaluateOne{}), value => evaluate_machine(clauses, batch, context, sensitive, value <> subjects, EvaluateOne{}))
    case WhenExpression{key, value, rest} batch EvaluateOne{}:
      case_when_value(evaluate_machine(key, batch, context, sensitive, subjects, EvaluateOne{}), case_subject(subjects), u => evaluate_machine(value, batch, context, sensitive, subjects, EvaluateOne{}), u => evaluate_machine(rest, batch, context, sensitive, subjects, EvaluateOne{}))
    case ElseExpression{value} batch EvaluateOne{}:
      evaluate_machine(value, batch, context, sensitive, subjects, EvaluateOne{})
    case NoCaseMatch{} batch EvaluateOne{}:
      Failure{"No block matched the switch value '" ++ ruby_render(case_subject(subjects), False{}, False{}) ++ "'"}
    case MidExpression{value, offset, length} batch EvaluateOne{}:
      mid_text(evaluate_machine(value, batch, context, sensitive, subjects, EvaluateOne{}), u => evaluate_machine(offset, batch, context, sensitive, subjects, EvaluateOne{}), u => evaluate_machine(length, batch, context, sensitive, subjects, EvaluateOne{}))
    case ContainsExpression{needle, haystack} batch EvaluateOne{}:
      contains_haystack(evaluate_machine(haystack, batch, context, sensitive, subjects, EvaluateOne{}), u => evaluate_machine(needle, batch, context, sensitive, subjects, EvaluateOne{}))
    case ArrayLiteral{elements} batch EvaluateOne{}:
      array_value(evaluate_machine(elements, batch, context, sensitive, subjects, EvaluateOne{}))
    case Access{structure, index} batch EvaluateOne{}:
      access_value(evaluate_machine(structure, batch, context, sensitive, subjects, EvaluateOne{}), u => evaluate_machine(index, batch, context, sensitive, subjects, EvaluateOne{}))
    case CountOneExpression{a} batch EvaluateOne{}:
      count_single(evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}))
    case CountManyExpression{arguments, count} batch EvaluateOne{}:
      Number{count}
    case EmptyArguments{} batch EvaluateOne{}:
      EmptyArgumentValues{}
    case Argument{a, validation} batch EvaluateOne{}:
      ArgumentValue{validate_argument(validation, evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}))}
    case Arguments{a, b} batch EvaluateOne{}:
      x y = evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}) evaluate_machine(b, batch, context, sensitive, subjects, EvaluateOne{})
      ArgumentPair{x, y}
    case FunctionCall{kind, arguments} batch EvaluateOne{}:
      call(kind, evaluate_machine(arguments, batch, context, sensitive, subjects, EvaluateOne{}))
    case Literal{v} batch EvaluateOne{}:
      v
    case Variable{name} batch EvaluateOne{}:
      lookup(context, name, sensitive)
    case Add{a, b} batch EvaluateOne{}:
      x y = evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}) evaluate_machine(b, batch, context, sensitive, subjects, EvaluateOne{})
      add(x, y)
    case Divide{a, b} batch EvaluateOne{}:
      x y = evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}) evaluate_machine(b, batch, context, sensitive, subjects, EvaluateOne{})
      divide(x, y)
    case Multiply{a, b} batch EvaluateOne{}:
      x y = evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}) evaluate_machine(b, batch, context, sensitive, subjects, EvaluateOne{})
      multiply(x, y)
    case And{a, b} batch EvaluateOne{}:
      logical_left(evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}), True{}, u => evaluate_machine(b, batch, context, sensitive, subjects, EvaluateOne{}))
    case Or{a, b} batch EvaluateOne{}:
      logical_left(evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}), False{}, u => evaluate_machine(b, batch, context, sensitive, subjects, EvaluateOne{}))
    case Xor{a, b} batch EvaluateOne{}:
      x y = evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}) evaluate_machine(b, batch, context, sensitive, subjects, EvaluateOne{})
      logical_xor(x, y)
    case PrefixNot{a} batch EvaluateOne{}:
      logical_not(evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}))
    case CoerceNumber{a} batch EvaluateOne{}:
      require_numeric(evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}))
    case Compare{op, a, b} batch EvaluateOne{}:
      x y = evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}) evaluate_machine(b, batch, context, sensitive, subjects, EvaluateOne{})
      compare(x, y, op)
    case Round{a, places, mode} batch EvaluateOne{}:
      x p = evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}) evaluate_machine(places, batch, context, sensitive, subjects, EvaluateOne{})
      round(x, p, mode)
    case Negate{a} batch EvaluateOne{}:
      negate(evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}))
    case Subtract{a, b} batch EvaluateOne{}:
      x y = evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}) evaluate_machine(b, batch, context, sensitive, subjects, EvaluateOne{})
      subtract(x, y)
    case Not{a} batch EvaluateOne{}:
      logical_not(evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}))
    case If{c, a, b} batch EvaluateOne{}:
      choose(evaluate_machine(c, batch, context, sensitive, subjects, EvaluateOne{}), u => evaluate_machine(a, batch, context, sensitive, subjects, EvaluateOne{}), u => evaluate_machine(b, batch, context, sensitive, subjects, EvaluateOne{}))
    case e batch mode:
      Failure{"Invalid evaluation batch"}

def evaluate_scoped(e: Expr, context: List<&2, Binding>, sensitive: Bool, subjects: List<&2, Value>) -> Value:
  evaluate_machine(prepare_expression(e), EmptyArgumentValues{}, context, sensitive, subjects, EvaluateOne{})

def evaluate_in(e: Expr, context: List<&2, Binding>, sensitive: Bool) -> Value:
  evaluate_scoped(e, context, sensitive, Nil{})

def evaluate(e: Expr) -> Value:
  evaluate_in(e, Nil{}, False{})

def show(value: Value) -> String:
  match value:
    case SymbolValue{s}:
      s
    case HashNil{}:
      "{}"
    case HashEntry{key, value, tail}:
      ruby_render(HashEntry{key, value, tail}, False{}, False{})
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
    case SymbolValue{s}:
      "symbol:" ++ s
    case HashNil{}:
      Bool.pick(String, tail_mode, "}", "hash:{}")
    case HashEntry{key, value, tail}:
      +a = snapshot_render(key, False{})
      +b = snapshot_render(value, False{})
      Bool.pick(String, tail_mode, "", "hash:{") ++ Nat.show(String.length(a)) ++ ":" ++ a ++ Nat.show(String.length(b)) ++ ":" ++ b ++ snapshot_render(tail, True{})
    case Failure{e}:
      failure_snapshot(e)

def snapshot(value: Value) -> String:
  snapshot_render(value, False{})

def class_snapshot(value: Value) -> String:
  match value:
    case SymbolValue{s}:
      "class:Symbol"
    case HashNil{}:
      "class:Hash"
    case HashEntry{key, item, tail}:
      "class:Hash"
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
