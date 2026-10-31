import Base
import ./decimal.bend as Decimal
import ./division.bend as Division
import ./lexer.bend as Lex
import ./string.bend as StringOps
import ./unicode.bend as Unicode
import ./remainder.bend as Remainder
import ./bits.bend as Bits
import ./binary64.bend as Binary
import ./binary64_decimal.bend as BinaryDecimal
import ./binary64_format.bend as BinaryFormat
import ./numeric_float.bend as FloatNumeric
import ./binary64_bigdecimal.bend as FloatBigDecimal
import ./float_round.bend as FloatRound
import ./float_index.bend as FloatIndex

type ReferenceKind is Data:
  ClassReferenceKind{}
  ModuleReferenceKind{}

# Small integers use Nat; larger integers and decimals use exact digit lists.
type Value is Data:
  Number{value: Nat}
  IntegerNumber{value: Decimal.Decimal}
  NegativeInteger{value: Decimal.Decimal}
  DecimalNumber{value: Decimal.Decimal}
  NegativeNumber{value: Decimal.Decimal}
  FloatNumber{value: Binary.Float}
  DecimalNonfinite{value: FloatNumeric.Special}
  Logical{value: Bool}
  NullValue{}
  TextValue{value: String}
  SymbolValue{value: String}
  StoredExpression{expression: Expr, sensitive: Bool}
  NamedReference{kind: ReferenceKind, name: String, ancestors: List<&2, String>}
  RangeValue{first: Value, last: Value, exclude_end: Bool}
  MemberIndex{name: String}
  HashNil{}
  HashEntry{key: Value, value: Value, tail: Value}
  ArrayNil{}
  ArrayCons{head: Value, tail: Value}
  ArgumentValue{value: Value}
  ArgumentPair{left: Value, right: Value}
  EmptyArgumentValues{}
  Failure{message: String}
  Raised{class_name: String, message: String}

type Comparison is Data:
  EqualTo{}
  NotEqualTo{}
  LessThan{}
  LessOrEqual{}
  GreaterThan{}
  GreaterOrEqual{}

type DecimalMath is Data:
  DecimalDivide{}
  DecimalModulo{}

type NumericInputs is Data:
  NumericValues{values: List<&2, Value>}
  NumericError{value: Value}

def float_words(high: U32, low: U32) -> Value:
  FloatNumber{Binary.from_words(high, low)}

def decimal_infinity(negative: Bool) -> Value:
  DecimalNonfinite{FloatNumeric.Infinity{negative}}

def decimal_nan() -> Value:
  DecimalNonfinite{FloatNumeric.NotANumber{}}

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
  PluckItems{}
  FilterItems{}
  AllItems{}
  AnyItems{}

type Expr is Data:
  Literal{value: Value}
  Variable{name: String}
  Add{left: Expr, right: Expr}
  Multiply{left: Expr, right: Expr}
  Divide{left: Expr, right: Expr}
  Modulo{left: Expr, right: Expr}
  Percentage{operand: Expr}
  Bitwise{operation: Bits.BitwiseOperation, left: Expr, right: Expr}
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

def is_unbound_message(+message: String) -> Bool:
  Bool.or(String.starts_with(message, "no value provided for variables: "), String.starts_with(message, "Unbound variable: "))

def is_range_message(+message: String) -> Bool:
  Bool.or(String.eq(message, "Index exceeds Ruby signed long range"), String.eq(message, "shift width too big"))

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

def float_numeric(value: Value) -> Maybe<&2, FloatNumeric.Number>:
  match value:
    case Number{n}:
      Some{FloatNumeric.Exact{FloatNumeric.IntegerKind{}, False{}, Decimal.from_nat(n)}}
    case IntegerNumber{n}:
      Some{FloatNumeric.Exact{FloatNumeric.IntegerKind{}, False{}, n}}
    case NegativeInteger{n}:
      Some{FloatNumeric.Exact{FloatNumeric.IntegerKind{}, True{}, n}}
    case DecimalNumber{n}:
      Some{FloatNumeric.Exact{FloatNumeric.DecimalKind{}, False{}, n}}
    case NegativeNumber{n}:
      Some{FloatNumeric.Exact{FloatNumeric.DecimalKind{}, True{}, n}}
    case FloatNumber{n}:
      Some{FloatNumeric.Floating{n}}
    case DecimalNonfinite{n}:
      Some{FloatNumeric.Exceptional{n}}
    case value:
      None{}

def from_float_numeric(value: FloatNumeric.Number) -> Value:
  match value:
    case FloatNumeric.Exact{FloatNumeric.IntegerKind{}, negative, +magnitude}:
      Bool.pick(Value, negative, NegativeInteger{magnitude}, compact(magnitude))
    case FloatNumeric.Exact{FloatNumeric.DecimalKind{}, negative, +magnitude}:
      Bool.pick(Value, negative, NegativeNumber{magnitude}, DecimalNumber{magnitude})
    case FloatNumeric.Floating{value}:
      FloatNumber{value}
    case FloatNumeric.Exceptional{value}:
      DecimalNonfinite{value}

def floating_result(result: FloatNumeric.CalculationResult) -> Value:
  match result:
    case FloatNumeric.Calculated{value}:
      from_float_numeric(value)
    case FloatNumeric.Rejected{message}:
      Failure{message}
    case FloatNumeric.NativeRejected{class_name, message}:
      Raised{class_name, message}

def floating_operands(operation: FloatNumeric.Operation, a: Maybe<&2, FloatNumeric.Number>, b: Maybe<&2, FloatNumeric.Number>) -> Value:
  match a b:
    case Some{a} Some{b}:
      floating_result(FloatNumeric.operate(operation, a, b))
    case a b:
      Failure{"Expected numbers"}

def has_extended_numeric(value: Value) -> Bool:
  match value:
    case FloatNumber{value}:
      True{}
    case DecimalNonfinite{value}:
      True{}
    case value:
      False{}

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
    case FloatNumber{value}:
      Binary.sign(value)
    case DecimalNonfinite{FloatNumeric.Infinity{negative}}:
      negative
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

def is_null_value(value: Value) -> Bool:
  match value:
    case NullValue{}:
      True{}
    case value:
      False{}

def range_separator(excluded: Bool) -> String:
  Bool.pick(String, excluded, "...", "..")

def ruby_render(value: Value, +inspect: Bool, tail_mode: Bool) -> String:
  match value:
    case FloatNumber{value}:
      BinaryFormat.show(value)
    case DecimalNonfinite{value}:
      FloatNumeric.special_text(value)
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
      Bool.pick(String, inspect, StringOps.symbol_inspect(s), s)
    case NamedReference{kind, name, ancestors}:
      name
    case RangeValue{+first, +last, excluded}:
      ruby_render(first, Bool.and(inspect, Bool.or(Bool.not(is_null_value(first)), is_null_value(last))), False{}) ++ range_separator(excluded) ++ ruby_render(last, Bool.and(inspect, Bool.or(Bool.not(is_null_value(last)), is_null_value(first))), False{})
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
    case FloatNumber{value}:
      FloatNumber{value}
    case DecimalNonfinite{value}:
      DecimalNonfinite{value}
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
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
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
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case right:
      Failure{"Expected an array"}

# Ruby array equality does not coerce string elements to numbers. The pinned
# BigDecimal implementation compares equal to integral values in subtraction.
def reference_type_name(kind: ReferenceKind) -> String:
  match kind:
    case ClassReferenceKind{}:
      "Class"
    case ModuleReferenceKind{}:
      "Module"

def named_identity(a_kind: ReferenceKind, a_name: String, b_kind: ReferenceKind, b_name: String) -> Bool:
  Bool.and(String.eq(reference_type_name(a_kind), reference_type_name(b_kind)), String.eq(a_name, b_name))

def named_ancestor(names: List<&2, String>, +name: String) -> Bool:
  match names:
    case Nil{}:
      False{}
    case head <> rest:
      Bool.or(String.eq(head, name), named_ancestor(rest, name))

def hash_key_equal(a: Value, b: Value) -> Bool:
  match a b:
    case TextValue{x} TextValue{y}:
      String.eq(x, y)
    case SymbolValue{x} SymbolValue{y}:
      String.eq(x, y)
    case NamedReference{ka, a, pa} NamedReference{kb, b, pb}:
      named_identity(ka, a, kb, b)
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
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case value:
      next(value)

def hash_get(hash: Value, key: Value) -> Value:
  hash_get_found(hash_find(hash, key))

def numeric_is_equal(order: Maybe<&2, Cmp>) -> Bool:
  match order:
    case Some{EQ{}}:
      True{}
    case order:
      False{}

def extended_equal(a: Maybe<&2, FloatNumeric.Number>, b: Maybe<&2, FloatNumeric.Number>) -> Bool:
  match a b:
    case Some{a} Some{b}:
      numeric_is_equal(FloatNumeric.compare(a, b))
    case a b:
      False{}

def value_equal(a: Value, b: Value, +strict: Bool) -> Bool:
  match a b:
    case FloatNumber{a} b:
      extended_equal(Some{FloatNumeric.Floating{a}}, float_numeric(b))
    case a FloatNumber{b}:
      extended_equal(float_numeric(a), Some{FloatNumeric.Floating{b}})
    case DecimalNonfinite{a} b:
      extended_equal(Some{FloatNumeric.Exceptional{a}}, float_numeric(b))
    case a DecimalNonfinite{b}:
      extended_equal(float_numeric(a), Some{FloatNumeric.Exceptional{b}})
    case RangeValue{af, al, ax} RangeValue{bf, bl, bx}:
      Bool.and(Cmp.is_eq(Bool.cmp(ax, bx)), Bool.and(value_equal(af, bf, True{}), value_equal(al, bl, True{})))
    case HashNil{} HashNil{}:
      True{}
    case HashEntry{+key, value, tail} +b:
      Bool.and(hash_equal_found(hash_find(b, key), other => value_equal(value, other, strict)), value_equal(tail, hash_remove(b, key), strict))
    case SymbolValue{x} SymbolValue{y}:
      String.eq(x, y)
    case NamedReference{ka, a, pa} NamedReference{kb, b, pb}:
      named_identity(ka, a, kb, b)
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

# Ruby eql? is directional: BigDecimal accepts equal Integers, while Integer
# rejects BigDecimal. Hash-backed set operations additionally require matching
# hashes; the pinned BigDecimal hashes distinguish numeric classes and zero sign.
type NumericOperand is Data:
  Magnitude{negative: Bool, value: Decimal.Decimal}
  InvalidNumeric{message: String}
  RaisedNumeric{class_name: String, message: String}

def binary_numeric_operand(value: BinaryDecimal.Exact) -> NumericOperand:
  match value:
    case BinaryDecimal.Finite{negative, magnitude}:
      Magnitude{negative, magnitude}
    case BinaryDecimal.Infinite{negative}:
      RaisedNumeric{"FloatDomainError", Bool.pick(String, negative, "-Infinity", "Infinity")}
    case BinaryDecimal.NotANumber{}:
      RaisedNumeric{"FloatDomainError", "NaN"}

def numeric_operand_value(value: Value) -> NumericOperand:
  match value:
    case FloatNumber{value}:
      binary_numeric_operand(BinaryDecimal.to_exact(value))
    case DecimalNonfinite{value}:
      RaisedNumeric{"FloatDomainError", FloatNumeric.special_text(value)}
    case Raised{class_name, message}:
      RaisedNumeric{class_name, message}
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

def ruby_type_name(value: Value) -> String:
  match value:
    case FloatNumber{value}:
      "Float"
    case DecimalNonfinite{value}:
      "BigDecimal"
    case Number{n}:
      "Integer"
    case IntegerNumber{n}:
      "Integer"
    case NegativeInteger{n}:
      "Integer"
    case DecimalNumber{n}:
      "BigDecimal"
    case NegativeNumber{n}:
      "BigDecimal"
    case TextValue{s}:
      "String"
    case SymbolValue{s}:
      "Symbol"
    case NamedReference{kind, name, ancestors}:
      reference_type_name(kind)
    case RangeValue{first, last, excluded}:
      "Range"
    case Logical{True{}}:
      "TrueClass"
    case Logical{False{}}:
      "FalseClass"
    case NullValue{}:
      "NilClass"
    case ArrayNil{}:
      "Array"
    case ArrayCons{head, tail}:
      "Array"
    case HashNil{}:
      "Hash"
    case HashEntry{key, value, tail}:
      "Hash"
    case value:
      "Object"

def array_length(value: Value) -> Nat:
  match value:
    case ArrayCons{head, tail}:
      1n+array_length(tail)
    case value:
      0n

def bitwise_name(kind: Bits.BitwiseOperation) -> String:
  match kind:
    case Bits.BitOr{}:
      "BitwiseOr"
    case Bits.BitAnd{}:
      "BitwiseAnd"
    case Bits.ShiftLeft{}:
      "BitwiseShiftLeft"
    case Bits.ShiftRight{}:
      "BitwiseShiftRight"

def value_equal_same_type(+a: Value, +b: Value) -> Bool:
  match a:
    case FloatNumber{value}:
      False{}
    case DecimalNonfinite{value}:
      False{}
    case Number{n}:
      False{}
    case IntegerNumber{n}:
      False{}
    case NegativeInteger{n}:
      False{}
    case DecimalNumber{n}:
      False{}
    case NegativeNumber{n}:
      False{}
    case a:
      value_equal(a, b, True{})

def set_numeric_magnitudes(a: NumericOperand, b: NumericOperand) -> Bool:
  match a b:
    case Magnitude{sa, +x} Magnitude{sb, +y}:
      Bool.and(Cmp.is_eq(Decimal.compare(x, y)), Bool.or(Cmp.is_eq(Bool.cmp(sa, sb)), Bool.and(Decimal.is_zero(x), Decimal.is_zero(y))))
    case a b:
      False{}

def set_exact_numeric_equal(+a: Value, +b: Value, +hashed: Bool) -> Bool:
  numeric = set_numeric_magnitudes(numeric_operand_value(a), numeric_operand_value(b))
  same_class = String.eq(ruby_type_name(a), ruby_type_name(b))
  class_ok = Bool.or(same_class, Bool.and(Bool.not(hashed), String.eq(ruby_type_name(a), "BigDecimal")))
  sign_ok = Bool.or(Bool.not(hashed), Cmp.is_eq(Bool.cmp(has_negative_sign(a), has_negative_sign(b))))
  Bool.and(numeric, Bool.and(class_ok, sign_ok))

def set_numeric_equal(a: Value, b: Value, hashed: Bool) -> Bool:
  match a b:
    case FloatNumber{a} FloatNumber{b}:
      numeric_is_equal(Binary.compare(a, b))
    case FloatNumber{a} b:
      False{}
    case +a FloatNumber{b}:
      Bool.and(Bool.and(Bool.not(hashed), String.eq(ruby_type_name(a), "BigDecimal")), extended_equal(float_numeric(a), Some{FloatNumeric.Floating{b}}))
    case DecimalNonfinite{a} DecimalNonfinite{b}:
      extended_equal(Some{FloatNumeric.Exceptional{a}}, Some{FloatNumeric.Exceptional{b}})
    case a b:
      set_exact_numeric_equal(a, b, hashed)

def set_equal(a: Value, b: Value, +hashed: Bool) -> Bool:
  match a b:
    case HashNil{} HashNil{}:
      True{}
    case HashEntry{+key, value, tail} +b:
      Bool.and(hash_equal_found(hash_find(b, key), other => set_equal(value, other, hashed)), set_equal(tail, hash_remove(b, key), hashed))
    case ArrayNil{} ArrayNil{}:
      True{}
    case ArrayCons{ah, at} ArrayCons{bh, bt}:
      Bool.and(set_equal(ah, bh, hashed), set_equal(at, bt, hashed))
    case RangeValue{af, al, ax} RangeValue{bf, bl, bx}:
      Bool.and(Cmp.is_eq(Bool.cmp(ax, bx)), Bool.and(set_equal(af, bf, hashed), set_equal(al, bl, hashed)))
    case +a +b:
      Bool.or(set_numeric_equal(a, b, hashed), value_equal_same_type(a, b))

def set_contains(array: Value, +candidate: Value, +hashed: Bool) -> Bool:
  match array:
    case ArrayCons{head, tail}:
      Bool.or(set_equal(candidate, head, hashed), set_contains(tail, candidate, hashed))
    case array:
      False{}

def array_contains(array: Value, candidate: Value) -> Bool:
  set_contains(array, candidate, False{})

def array_keep(remove: Bool, head: Value, tail: Value) -> Value:
  match remove:
    case True{}:
      tail
    case False{}:
      ArrayCons{head, tail}

def array_difference_items(left: Value, +right: Value, +hashed: Bool) -> Value:
  match left:
    case ArrayCons{+head, tail}:
      array_keep(set_contains(right, head, hashed), head, array_difference_items(tail, right, hashed))
    case left:
      ArrayNil{}

def array_difference(+left: Value, +right: Value) -> Value:
  array_difference_items(left, right, Bool.and(Nat.is_gt(array_length(left), 16n), Nat.is_gt(array_length(right), 16n)))

def array_set_items(items: Value, +right: Value, +seen: Value, +intersection: Bool, +hashed: Bool) -> Value:
  match items:
    case ArrayCons{+head, tail}:
      +keep = Bool.and(Bool.not(set_contains(seen, head, hashed)), Bool.or(Bool.not(intersection), set_contains(right, head, hashed)))
      array_keep(Bool.not(keep), head, array_set_items(tail, right, Bool.pick(Value, keep, ArrayCons{head, seen}, seen), intersection, hashed))
    case items:
      ArrayNil{}

def array_set_operation(kind: Bits.BitwiseOperation, +left: Value, +right: Value) -> Value:
  match kind:
    case Bits.BitOr{}:
      array_set_items(array_append(left, right), ArrayNil{}, ArrayNil{}, False{}, Nat.is_gt(Nat.add(array_length(left), array_length(right)), 16n))
    case kind:
      array_set_items(left, right, ArrayNil{}, True{}, Bool.or(Nat.is_gt(array_length(left), 16n), Nat.is_gt(array_length(right), 16n)))

def array_bitwise(+kind: Bits.BitwiseOperation, left: Value, right: Value) -> Value:
  match right:
    case ArrayNil{}:
      array_set_operation(kind, left, ArrayNil{})
    case ArrayCons{head, tail}:
      array_set_operation(kind, left, ArrayCons{head, tail})
    case right:
      Failure{"Dentaku::AST::" ++ bitwise_name(kind) ++ " requires integer operands, but got " ++ ruby_type_name(right)}

def array_subtract(left: Value, right: Value) -> Value:
  match right:
    case ArrayNil{}:
      left
    case ArrayCons{head, tail}:
      array_difference(left, ArrayCons{head, tail})
    case Failure{e}:
      Failure{e}
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
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
      Bool.pick(Value, List.is_empty(&2, U32, digits), ArrayNil{}, Failure{"negative argument"})
    case False{}:
      array_repeat_fits(Nat.is_le(List.length(&2, U32, digits), 14n), digits, array)

def array_repeat_decimal(value: Decimal.Decimal, negative_count: Bool, array: Value) -> Value:
  match value:
    case Decimal.Exact{digits, scale}:
      array_repeat_digits(negative_count, Decimal.normalize_digits(Decimal.integer_digits(scale, digits)), array)

def array_repeat_operand(value: NumericOperand, array: Value) -> Value:
  match value:
    case Magnitude{negative, magnitude}:
      array_repeat_decimal(magnitude, negative, array)
    case InvalidNumeric{message}:
      Failure{message}
    case RaisedNumeric{error_class, error_message}:
      Failure{error_message}

def array_repeat_float(result: FloatIndex.IndexResult, array: Value) -> Value:
  match result:
    case FloatIndex.Index{sign, magnitude}:
      array_repeat_decimal(magnitude, sign, array)
    case FloatIndex.OutOfRange{message}:
      Failure{message}

def array_multiply(array: Value, count: Value) -> Value:
  match count:
    case FloatNumber{value}:
      array_repeat_float(FloatIndex.convert(value), array)
    case DecimalNonfinite{value}:
      Failure{FloatNumeric.special_text(value)}
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
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
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
    case Raised{error_class, error_message} b:
      Raised{error_class, error_message}
    case a Failure{e}:
      Failure{e}
    case a Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case a b:
      Failure{"Expected numbers"}

def add_cast(+a: Value, +b: Value) -> Value:
  decimal_zero_sign(Bool.and(has_negative_sign(a), has_negative_sign(b)), numeric_result(Bool.and(is_integer(a), is_integer(b)), add_values(strip_integer(a), strip_integer(b))))

def add_extended(extended: Bool, +a: Value, +b: Value) -> Value:
  match extended a:
    case True{} ArrayNil{}:
      add_cast(ArrayNil{}, b)
    case True{} ArrayCons{head, tail}:
      add_cast(ArrayCons{head, tail}, b)
    case True{} a:
      floating_operands(FloatNumeric.Sum{}, float_numeric(a), float_numeric(b))
    case False{} a:
      add_cast(a, b)

def add_dispatch(+a: Value, +b: Value) -> Value:
  match a b:
    case Failure{message} b:
      Failure{message}
    case Raised{class_name, message} b:
      Raised{class_name, message}
    case a Failure{message}:
      Failure{message}
    case a Raised{class_name, message}:
      Raised{class_name, message}
    case +a +b:
      add_extended(Bool.or(has_extended_numeric(a), has_extended_numeric(b)), a, b)

def add(a: Value, b: Value) -> Value:
  match a:
    case Failure{e}:
      Failure{e}
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case a:
      add_dispatch(cast_numeric(a), cast_numeric(b))

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
    case Raised{error_class, error_message} b:
      Raised{error_class, error_message}
    case a Failure{e}:
      Failure{e}
    case a Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case a b:
      Failure{"Expected numbers"}

def multiply_cast(+a: Value, +b: Value) -> Value:
  decimal_zero_sign(Bool.xor(has_negative_sign(a), has_negative_sign(b)), numeric_result(Bool.and(is_integer(a), is_integer(b)), multiply_values(strip_integer(a), strip_integer(b))))

def multiply_extended(extended: Bool, a: Value, b: Value) -> Value:
  match extended a:
    case True{} ArrayNil{}:
      multiply_cast(ArrayNil{}, b)
    case True{} ArrayCons{head, tail}:
      multiply_cast(ArrayCons{head, tail}, b)
    case True{} a:
      floating_operands(FloatNumeric.Product{}, float_numeric(a), float_numeric(b))
    case False{} a:
      multiply_cast(a, b)

def multiply_dispatch(+a: Value, +b: Value) -> Value:
  match a b:
    case Failure{message} b:
      Failure{message}
    case Raised{class_name, message} b:
      Raised{class_name, message}
    case a Failure{message}:
      Failure{message}
    case a Raised{class_name, message}:
      Raised{class_name, message}
    case +a +b:
      multiply_extended(Bool.or(has_extended_numeric(a), has_extended_numeric(b)), a, b)

def multiply(a: Value, b: Value) -> Value:
  multiply_dispatch(cast_numeric(a), cast_numeric(b))

def negate_value(value: Value) -> Value:
  match value:
    case FloatNumber{value}:
      FloatNumber{Binary.negate(value)}
    case DecimalNonfinite{FloatNumeric.Infinity{negative}}:
      DecimalNonfinite{FloatNumeric.Infinity{Bool.not(negative)}}
    case DecimalNonfinite{FloatNumeric.NotANumber{}}:
      DecimalNonfinite{FloatNumeric.NotANumber{}}
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
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
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
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case c:
      yes(Unit{})

def logical_not(v: Value) -> Value:
  match v:
    case Logical{b}:
      Logical{Bool.not(b)}
    case Failure{e}:
      Failure{e}
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
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
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
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
    case Raised{class_name, message}:
      Raised{class_name, message}
    case Failure{+e}:
      logical_unbound(is_unbound_message(e), Failure{e}, is_and, next)
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
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case value:
      Failure{"Incompatible logical operand"}

def xor_values(a: Value, b: Value) -> Value:
  match a b:
    case Logical{x} Logical{y}:
      Logical{Bool.xor(x, y)}
    case Failure{e} b:
      Failure{e}
    case Raised{error_class, error_message} b:
      Raised{error_class, error_message}
    case a Failure{e}:
      Failure{e}
    case a Raised{error_class, error_message}:
      Raised{error_class, error_message}
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
      Unicode.lower(name)

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
      Failure{"no value provided for variables: " ++ normalize(sensitive, name)}
    case Bound{key, value} <> tail:
      found(String.eq(normalize(sensitive, key), normalize(sensitive, name)), value, u => lookup(tail, name, sensitive))
    case ScopedBound{key, value} <> tail:
      found(String.eq(key, normalize(sensitive, name)), value, u => lookup(tail, name, sensitive))
    case SymbolBound{key, value} <> tail:
      found(String.eq(normalize(sensitive, key), normalize(sensitive, name)), value, u => lookup(tail, name, sensitive))

def found_binding(same: Bool, value: Value, rest: Unit -> Maybe<&2, Value>) -> Maybe<&2, Value>:
  match same:
    case True{}:
      Some{value}
    case False{}:
      rest(Unit{})

# Presence is independent of the bound value, including null and false.
def find_binding(context: List<&2, Binding>, +name: String, +sensitive: Bool) -> Maybe<&2, Value>:
  match context:
    case Nil{}:
      None{}
    case Bound{key, value} <> tail:
      found_binding(String.eq(normalize(sensitive, key), normalize(sensitive, name)), value, u => find_binding(tail, name, sensitive))
    case ScopedBound{key, value} <> tail:
      found_binding(String.eq(key, normalize(sensitive, name)), value, u => find_binding(tail, name, sensitive))
    case SymbolBound{key, value} <> tail:
      found_binding(String.eq(normalize(sensitive, key), normalize(sensitive, name)), value, u => find_binding(tail, name, sensitive))

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
      Bool.pick(Value, is_range_message(message), value, NullValue{})
    case value:
      value

def round_numeric(value: Value, +target: Nat, before: Nat, mode: Decimal.Rounding) -> Value:
  match value:
    case FloatNumber{value}:
      floating_result(FloatRound.round(mode, target, before, value))
    case DecimalNonfinite{+value}:
      Bool.pick(Value, Nat.is_gt(target, 0n), DecimalNonfinite{value}, Raised{"FloatDomainError", FloatNumeric.special_text(value)})
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
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case value:
      Failure{"Expected numbers"}

def round_direction(negative_places: Bool, count: Nat, value: Value, mode: Decimal.Rounding) -> Value:
  match negative_places:
    case False{}:
      round_numeric(value, count, 0n, mode)
    case True{}:
      round_numeric(value, 0n, count, mode)

def precision_range_message(fits_long: Bool, digits: List<&2, U32>, +negative: Bool) -> Value:
  match fits_long:
    case True{}:
      Raised{"RangeError", "integer " ++ Bool.pick(String, negative, "-", "") ++ Decimal.show(Decimal.Exact{digits, 0n}) ++ Bool.pick(String, negative, " too small", " too big") ++ " to convert to `int'"}
    case False{}:
      Raised{"RangeError", "bignum too big to convert into `long'"}

def precision_range_digits(+digits: List<&2, U32>, +negative: Bool) -> Value:
  limit : List<&2, U32> = [Bool.pick(U32, negative, 8, 7), 0, 8, 5, 7, 7, 4, 5, 8, 6, 3, 0, 2, 7, 3, 3, 2, 2, 9]
  precision_range_message(Bool.not(Cmp.is_gt(Decimal.compare_digits(digits, limit))), digits, negative)

def precision_range(digits: List<&2, U32>, negative: Bool, value: Value) -> Value:
  match value:
    case FloatNumber{value}:
      precision_range_digits(digits, negative)
    case value:
      Failure{"Rounding precision exceeds supported index range"}

def round_precision_fits(fits: Bool, digits: List<&2, U32>, negative_places: Bool, value: Value, mode: Decimal.Rounding) -> Value:
  match fits:
    case True{}:
      round_direction(negative_places, Decimal.coefficient(digits), value, mode)
    case False{}:
      precision_range(digits, negative_places, value)

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
    case Raised{error_class, error_message} places:
      Raised{error_class, error_message}
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
    case value Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case value places:
      Failure{"Expected numeric rounding precision"}


def precision_projection(value: BinaryDecimal.Exact) -> Value:
  match value:
    case BinaryDecimal.Finite{negative, Decimal.Exact{digits, scale}}:
      from_float_numeric(FloatNumeric.exact_result(FloatNumeric.IntegerKind{}, negative, Decimal.Exact{Decimal.normalize_digits(Decimal.integer_digits(scale, digits)), 0n}))
    case BinaryDecimal.Infinite{negative}:
      Raised{"FloatDomainError", Bool.pick(String, negative, "-Infinity", "Infinity")}
    case BinaryDecimal.NotANumber{}:
      Raised{"FloatDomainError", "NaN"}

def precision_numeric(value: Value) -> Value:
  match value:
    case FloatNumber{value}:
      precision_projection(BinaryDecimal.to_exact(value))
    case DecimalNonfinite{value}:
      Raised{"FloatDomainError", FloatNumeric.special_text(value)}
    case DecimalNumber{Decimal.Exact{digits, scale}}:
      compact(Decimal.Exact{Decimal.normalize_digits(Decimal.integer_digits(scale, digits)), 0n})
    case NegativeNumber{Decimal.Exact{digits, scale}}:
      from_float_numeric(FloatNumeric.exact_result(FloatNumeric.IntegerKind{}, True{}, Decimal.Exact{Decimal.normalize_digits(Decimal.integer_digits(scale, digits)), 0n}))
    case value:
      value

def rounding_precision(value: Value) -> Value:
  match value:
    case NullValue{}:
      Number{0n}
    case Logical{False{}}:
      Number{0n}
    case value:
      precision_numeric(require_numeric(value))

def round_validation(value: Value, places: Value, mode: Decimal.Rounding) -> Value:
  match mode:
    case Decimal.HalfAway{}:
      with_value(require_numeric(value), value => with_value(rounding_precision(places), places => round_values(value, places, Decimal.HalfAway{})))
    case mode:
      with_value(rounding_precision(places), places => with_value(require_numeric(value), value => round_values(value, places, mode)))

def round(value: Value, places: Value, mode: Decimal.Rounding) -> Value:
  match value places:
    case Failure{message} places:
      Failure{message}
    case Raised{class_name, message} places:
      Raised{class_name, message}
    case value Failure{message}:
      Failure{message}
    case value Raised{class_name, message}:
      Raised{class_name, message}
    case value places:
      round_validation(value, places, mode)

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
    case RaisedNumeric{error_class, error_message} b:
      Raised{error_class, error_message}
    case a InvalidNumeric{e}:
      Failure{e}
    case a RaisedNumeric{error_class, error_message}:
      Raised{error_class, error_message}

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
    case False{} RaisedNumeric{error_class, error_message}:
      Raised{error_class, error_message}

def divide_default_operands(a: NumericOperand, b: NumericOperand) -> Value:
  match b:
    case Magnitude{sy, +y}:
      divide_nonzero(Decimal.is_zero(y), a, sy, y)
    case InvalidNumeric{e}:
      Failure{e}
    case RaisedNumeric{error_class, error_message}:
      Raised{error_class, error_message}

def modulo_result(result: Remainder.RemainderResult) -> Value:
  match result:
    case Remainder.ZeroDivisor{}:
      Failure{"Division by zero"}
    case Remainder.Remainder{sign, value}:
      signed_result(sign, value)

def modulo_nonzero(zero: Bool, a: NumericOperand, sy: Bool, y: Decimal.Decimal) -> Value:
  match zero a:
    case True{} a:
      Failure{"Division by zero"}
    case False{} InvalidNumeric{message}:
      Failure{message}
    case False{} RaisedNumeric{error_class, error_message}:
      Raised{error_class, error_message}
    case False{} Magnitude{sx, x}:
      modulo_result(Remainder.remainder(x, y, sx, sy))

def modulo_operands(a: NumericOperand, b: NumericOperand) -> Value:
  match b:
    case InvalidNumeric{message}:
      Failure{message}
    case RaisedNumeric{error_class, error_message}:
      Raised{error_class, error_message}
    case Magnitude{sy, +y}:
      modulo_nonzero(Decimal.is_zero(y), a, sy, y)

def modulo_right_nonzero(zero: Bool, sy: Bool, y: Decimal.Decimal, left: Unit -> Value) -> Value:
  match zero:
    case True{}:
      Failure{"Division by zero"}
    case False{}:
      modulo_nonzero(False{}, numeric_operand(left(Unit{})), sy, y)

def modulo_right(right: NumericOperand, left: Unit -> Value) -> Value:
  match right:
    case InvalidNumeric{message}:
      Failure{message}
    case RaisedNumeric{error_class, error_message}:
      Raised{error_class, error_message}
    case Magnitude{sy, +y}:
      modulo_right_nonzero(Decimal.is_zero(y), sy, y, left)

def decimal_cast(profile: FloatBigDecimal.Profile, value: Value) -> Value:
  match value:
    case FloatNumber{value}:
      from_float_numeric(FloatNumeric.projected(FloatBigDecimal.from_float(profile, value)))
    case value:
      value

def special_modulo(a: FloatNumeric.Number, b: FloatNumeric.Number) -> Value:
  match a b:
    case FloatNumeric.Exact{kind, negative, magnitude} FloatNumeric.Exceptional{FloatNumeric.Infinity{sign}}:
      decimal_result(from_float_numeric(FloatNumeric.Exact{kind, negative, magnitude}))
    case a b:
      decimal_nan()

def decimal_special(operation: DecimalMath, a: Maybe<&2, FloatNumeric.Number>, b: Maybe<&2, FloatNumeric.Number>) -> Value:
  match operation a b:
    case DecimalDivide{} Some{a} Some{b}:
      from_float_numeric(FloatNumeric.projected(BinaryDecimal.to_exact(Binary.divide(FloatNumeric.proxy(a), FloatNumeric.proxy(b)))))
    case DecimalModulo{} Some{a} Some{b}:
      special_modulo(a, b)
    case operation a b:
      Failure{"Expected numbers"}

def decimal_binary(extended: Bool, operation: DecimalMath, a: Value, b: Value) -> Value:
  match extended operation:
    case True{} operation:
      decimal_special(operation, float_numeric(a), float_numeric(b))
    case False{} DecimalDivide{}:
      divide_default_operands(numeric_operand_value(a), numeric_operand_value(b))
    case False{} DecimalModulo{}:
      modulo_operands(numeric_operand_value(a), numeric_operand_value(b))

def decimal_prepared(operation: DecimalMath, +a: Value, +b: Value) -> Value:
  match a:
    case Failure{message}:
      Failure{message}
    case Raised{class_name, message}:
      Raised{class_name, message}
    case a:
      decimal_binary(Bool.or(has_extended_numeric(a), has_extended_numeric(b)), operation, a, b)

def decimal_nonzero(zero: Bool, operation: DecimalMath, right: Value, left: Unit -> Value) -> Value:
  match zero:
    case True{}:
      Failure{"Division by zero"}
    case False{}:
      decimal_prepared(operation, decimal_cast(FloatBigDecimal.Implicit{}, cast_numeric(left(Unit{}))), right)

def decimal_right_operand(operand: Maybe<&2, FloatNumeric.Number>, operation: DecimalMath, right: Value, left: Unit -> Value) -> Value:
  match operand:
    case Some{number}:
      decimal_nonzero(FloatNumeric.is_zero(number), operation, right, left)
    case None{}:
      Failure{"Expected numbers"}

def decimal_right_prepared(operation: DecimalMath, +right: Value, left: Unit -> Value) -> Value:
  match right:
    case Failure{message}:
      Failure{message}
    case Raised{class_name, message}:
      Raised{class_name, message}
    case right:
      decimal_right_operand(float_numeric(right), operation, right, left)

def decimal_right_value(operation: DecimalMath, right: Value, left: Unit -> Value) -> Value:
  decimal_right_prepared(operation, decimal_cast(FloatBigDecimal.ShortestText{}, cast_numeric(right)), left)

def divide(a: Value, b: Value) -> Value:
  decimal_right_value(DecimalDivide{}, b, u => a)

def modulo(a: Value, b: Value) -> Value:
  decimal_right_value(DecimalModulo{}, b, u => a)

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

def named_relation(+same: Bool, +subtype: Bool, supertype: Bool, inclusive: Bool) -> Value:
  Bool.pick(Value, Bool.or(same, Bool.or(subtype, supertype)), Logical{Bool.or(subtype, Bool.and(same, inclusive))}, NullValue{})

def compare_named(op: Comparison, +same: Bool, +subtype: Bool, +supertype: Bool) -> Value:
  match op:
    case EqualTo{}:
      Logical{same}
    case NotEqualTo{}:
      Logical{Bool.not(same)}
    case LessThan{}:
      named_relation(same, subtype, supertype, False{})
    case LessOrEqual{}:
      named_relation(same, subtype, supertype, True{})
    case GreaterThan{}:
      named_relation(same, supertype, subtype, False{})
    case GreaterOrEqual{}:
      named_relation(same, supertype, subtype, True{})

def supports_order(value: Value) -> Bool:
  match value:
    case Logical{b}:
      False{}
    case NullValue{}:
      False{}
    case ArrayNil{}:
      False{}
    case ArrayCons{head, tail}:
      False{}
    case RangeValue{first, last, excluded}:
      False{}
    case value:
      True{}

def missing_comparison_operator(op: Comparison) -> Value:
  match op:
    case LessThan{}:
      Failure{"Dentaku::AST::LessThan requires operands that respond to <"}
    case LessOrEqual{}:
      Failure{"Dentaku::AST::LessThanOrEqual requires operands that respond to <="}
    case GreaterThan{}:
      Failure{"Dentaku::AST::GreaterThan requires operands that respond to >"}
    case GreaterOrEqual{}:
      Failure{"Dentaku::AST::GreaterThanOrEqual requires operands that respond to >="}
    case op:
      Failure{"Incompatible comparison operands"}

def named_other_order(supported: Bool, op: Comparison) -> Value:
  match supported:
    case True{}:
      Failure{"compared with non class/module"}
    case False{}:
      missing_comparison_operator(op)

def compare_named_nonreference(op: Comparison, other: Value) -> Value:
  match op:
    case EqualTo{}:
      Logical{False{}}
    case NotEqualTo{}:
      Logical{True{}}
    case op:
      named_other_order(supports_order(other), op)

def other_named_order_message(other: Value, kind: ReferenceKind) -> Value:
  match other:
    case HashNil{}:
      Failure{"no implicit conversion of " ++ reference_type_name(kind) ++ " into Hash"}
    case HashEntry{key, item, rest}:
      Failure{"no implicit conversion of " ++ reference_type_name(kind) ++ " into Hash"}
    case other:
      Failure{"comparison of " ++ ruby_type_name(other) ++ " with " ++ reference_type_name(kind) ++ " failed"}

def other_named_order(supported: Bool, other: Value, kind: ReferenceKind, op: Comparison) -> Value:
  match supported:
    case True{}:
      other_named_order_message(other, kind)
    case False{}:
      missing_comparison_operator(op)

def compare_nonreference_named(+other: Value, kind: ReferenceKind, op: Comparison) -> Value:
  match op:
    case EqualTo{}:
      Logical{False{}}
    case NotEqualTo{}:
      Logical{True{}}
    case op:
      other_named_order(supports_order(other), other, kind, op)

def compare_range(a: Value, b: Value, op: Comparison) -> Value:
  match op:
    case EqualTo{}:
      Logical{value_equal(a, b, True{})}
    case NotEqualTo{}:
      Logical{Bool.not(value_equal(a, b, True{}))}
    case op:
      missing_comparison_operator(op)

def extended_order(order: Maybe<&2, Cmp>, op: Comparison) -> Value:
  match order op:
    case Some{order} op:
      apply_order(op, order)
    case None{} NotEqualTo{}:
      Logical{True{}}
    case None{} op:
      Logical{False{}}

def extended_comparison(a: Maybe<&2, FloatNumeric.Number>, b: Maybe<&2, FloatNumeric.Number>, op: Comparison) -> Value:
  match a b:
    case Some{a} Some{b}:
      extended_order(FloatNumeric.compare(a, b), op)
    case a b:
      incompatible_comparison(op)

def compare_values(a: Value, b: Value, op: Comparison) -> Value:
  match a b:
    case Failure{e} b:
      Failure{e}
    case Raised{error_class, error_message} b:
      Raised{error_class, error_message}
    case a Failure{e}:
      Failure{e}
    case a Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case FloatNumber{a} b:
      extended_comparison(Some{FloatNumeric.Floating{a}}, float_numeric(b), op)
    case a FloatNumber{b}:
      extended_comparison(float_numeric(a), Some{FloatNumeric.Floating{b}}, op)
    case DecimalNonfinite{a} b:
      extended_comparison(Some{FloatNumeric.Exceptional{a}}, float_numeric(b), op)
    case a DecimalNonfinite{b}:
      extended_comparison(float_numeric(a), Some{FloatNumeric.Exceptional{b}}, op)
    case RangeValue{first, last, excluded} b:
      compare_range(RangeValue{first, last, excluded}, b, op)
    case a RangeValue{first, last, excluded}:
      compare_range(a, RangeValue{first, last, excluded}, op)
    case NamedReference{ka, +a, pa} NamedReference{kb, +b, pb}:
      compare_named(op, named_identity(ka, a, kb, b), named_ancestor(pa, b), named_ancestor(pb, a))
    case NamedReference{kind, name, ancestors} b:
      compare_named_nonreference(op, b)
    case a NamedReference{kind, name, ancestors}:
      compare_nonreference_named(a, kind, op)
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

def comparator_native_result(value: Value) -> Value:
  match value:
    case Raised{+class_name, +message}:
      Bool.pick(Value, Bool.or(String.eq(class_name, "ArgumentError"), String.eq(class_name, "TypeError")), Failure{message}, Raised{class_name, message})
    case value:
      value

def compare(a: Value, b: Value, op: Comparison) -> Value:
  comparator_native_result(compare_values(cast_numeric(a), cast_numeric(b), op))

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
    case ArgumentValue{Raised{class_name, message}}:
      Some{Raised{class_name, message}}
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
    case Raised{error_class, error_message} kind:
      Raised{error_class, error_message}
    case right kind:
      Failure{"Incompatible logical operand"}

def logical_fold_guard(accumulator: Value, kind: FunctionKind, next: Bool -> Value) -> Value:
  match accumulator kind:
    case Failure{e} kind:
      Failure{e}
    case Raised{error_class, error_message} kind:
      Raised{error_class, error_message}
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
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
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

def access_float(result: FloatIndex.IndexResult, value: Value) -> Value:
  match result:
    case FloatIndex.Index{sign, magnitude}:
      access_numeric(magnitude, sign, value)
    case FloatIndex.OutOfRange{message}:
      Raised{"RangeError", message}

def access_index(value: Value, index: Value) -> Value:
  match index:
    case FloatNumber{value_index}:
      access_float(FloatIndex.convert(value_index), value)
    case IntegerNumber{n}:
      access_numeric(n, False{}, value)
    case NegativeInteger{n}:
      access_numeric(n, True{}, value)
    case Failure{e}:
      Failure{e}
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
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

def truncate_magnitude(value: Decimal.Decimal) -> Decimal.Decimal:
  match value:
    case Decimal.Exact{digits, places}:
      Decimal.Exact{Decimal.normalize_digits(Decimal.integer_digits(places, digits)), 0n}

def bitwise_decimal_operand(+kind: Bits.BitwiseOperation, sign: Bool, value: Decimal.Decimal) -> NumericOperand:
  match kind:
    case Bits.ShiftLeft{}:
      Magnitude{sign, truncate_magnitude(value)}
    case Bits.ShiftRight{}:
      Magnitude{sign, truncate_magnitude(value)}
    case kind:
      InvalidNumeric{"Dentaku::AST::" ++ bitwise_name(kind) ++ " requires integer operands, but got BigDecimal"}

def bitwise_float_projection(exact: BinaryDecimal.Exact, kind: Bits.BitwiseOperation) -> NumericOperand:
  match exact:
    case BinaryDecimal.Finite{sign, magnitude}:
      bitwise_decimal_operand(kind, sign, magnitude)
    case exact:
      binary_numeric_operand(exact)

def bitwise_float_operand(+value: Binary.Float, kind: Bits.BitwiseOperation) -> NumericOperand:
  match kind:
    case Bits.ShiftLeft{}:
      bitwise_float_projection(BinaryDecimal.to_exact(value), Bits.ShiftLeft{})
    case Bits.ShiftRight{}:
      bitwise_float_projection(BinaryDecimal.to_exact(value), Bits.ShiftRight{})
    case kind:
      InvalidNumeric{"Dentaku::AST::" ++ bitwise_name(kind) ++ " requires integer operands, but got Float"}

def bitwise_operand(value: Value, kind: Bits.BitwiseOperation, left: Bool) -> NumericOperand:
  match value left:
    case FloatNumber{value} False{}:
      bitwise_float_operand(value, kind)
    case Number{n} left:
      Magnitude{False{}, Decimal.from_nat(n)}
    case IntegerNumber{n} left:
      Magnitude{False{}, n}
    case NegativeInteger{n} left:
      Magnitude{True{}, n}
    case DecimalNumber{n} False{}:
      bitwise_decimal_operand(kind, False{}, n)
    case NegativeNumber{n} False{}:
      bitwise_decimal_operand(kind, True{}, n)
    case value left:
      InvalidNumeric{"Dentaku::AST::" ++ bitwise_name(kind) ++ " requires integer operands, but got " ++ ruby_type_name(value)}

def bitwise_result(result: Bits.BitwiseResult) -> Value:
  match result:
    case Bits.IntegerResult{sign, value}:
      integer_result(signed_result(sign, value))
    case Bits.ShiftTooWide{}:
      Failure{"shift width too big"}

def bitwise_operands(kind: Bits.BitwiseOperation, a: NumericOperand, b: NumericOperand) -> Value:
  match a b:
    case InvalidNumeric{message} b:
      Failure{message}
    case RaisedNumeric{error_class, error_message} b:
      Raised{error_class, error_message}
    case a InvalidNumeric{message}:
      Failure{message}
    case a RaisedNumeric{error_class, error_message}:
      Raised{error_class, error_message}
    case Magnitude{sa, a} Magnitude{sb, b}:
      bitwise_result(Bits.calculate(kind, sa, a, sb, b))

def bitwise_values(kind: Bits.BitwiseOperation, a: Value, b: Value) -> Value:
  match kind a:
    case Bits.BitAnd{} Logical{x}:
      Logical{Bool.and(x, truthy(b))}
    case Bits.BitOr{} Logical{x}:
      Logical{Bool.or(x, truthy(b))}
    case Bits.BitAnd{} NullValue{}:
      Logical{False{}}
    case Bits.BitOr{} NullValue{}:
      Logical{truthy(b)}
    case Bits.ShiftLeft{} TextValue{text}:
      Failure{"Mutable string shifts are not implemented"}
    case Bits.ShiftLeft{} ArrayNil{}:
      Failure{"Mutable array shifts are not implemented"}
    case Bits.ShiftLeft{} ArrayCons{head, tail}:
      Failure{"Mutable array shifts are not implemented"}
    case Bits.BitAnd{} ArrayNil{}:
      array_bitwise(Bits.BitAnd{}, ArrayNil{}, b)
    case Bits.BitAnd{} ArrayCons{head, tail}:
      array_bitwise(Bits.BitAnd{}, ArrayCons{head, tail}, b)
    case Bits.BitOr{} ArrayNil{}:
      array_bitwise(Bits.BitOr{}, ArrayNil{}, b)
    case Bits.BitOr{} ArrayCons{head, tail}:
      array_bitwise(Bits.BitOr{}, ArrayCons{head, tail}, b)
    case +kind a:
      bitwise_operands(kind, bitwise_operand(a, kind, True{}), bitwise_operand(b, kind, False{}))

def bitwise_right(kind: Bits.BitwiseOperation, a: Value, b: Value) -> Value:
  match b:
    case Failure{message}:
      Failure{message}
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case b:
      bitwise_values(kind, a, b)

def bitwise(kind: Bits.BitwiseOperation, a: Value, b: Value) -> Value:
  match a:
    case Failure{message}:
      Failure{message}
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case a:
      bitwise_right(kind, a, b)

def hash_keys(hash: Value) -> Value:
  match hash:
    case HashEntry{key, value, tail}:
      ArrayCons{key, hash_keys(tail)}
    case hash:
      ArrayNil{}

def member_dotted(hash: Value, +member: String) -> String:
  match hash:
    case HashEntry{key, value, tail}:
      +name = ruby_render(key, False{}, False{})
      Bool.pick(String, String.starts_with(name, member ++ "."), name, member_dotted(tail, member))
    case hash:
      ""

def member_missing(+hash: Value, +member: String) -> Value:
  +dotted = member_dotted(hash, member)
  Failure{"no key '" ++ member ++ "' in " ++ ruby_render(hash_keys(hash), True{}, False{}) ++ Bool.pick(String, String.eq(dotted, ""), "", "; member access only reads keys that look like identifiers, use brackets for '" ++ dotted ++ "'")}

def member_folded(hash: Value, +member: String, missing: Unit -> Value) -> Value:
  match hash:
    case HashEntry{key, value, tail}:
      found(String.eq(Unicode.fold(ruby_render(key, False{}, False{})), Unicode.fold(member)), value, u => member_folded(tail, member, missing))
    case hash:
      missing(Unit{})

def member_found(result: Maybe<&2, Value>, missing: Unit -> Value) -> Value:
  match result:
    case Some{value}:
      value
    case None{}:
      missing(Unit{})

def member_hash(+hash: Value, +member: String, sensitive: Bool) -> Value:
  member_found(hash_find(hash, TextValue{member}), u => member_found(hash_find(hash, SymbolValue{member}), u => Bool.pick(Value, sensitive, member_missing(hash, member), member_folded(hash, member, u => member_missing(hash, member)))))

def member_value(value: Value, member: String, sensitive: Bool) -> Value:
  match value:
    case HashNil{}:
      member_hash(HashNil{}, member, sensitive)
    case HashEntry{key, item, tail}:
      member_hash(HashEntry{key, item, tail}, member, sensitive)
    case NullValue{}:
      NullValue{}
    case Failure{message}:
      Failure{message}
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case value:
      Failure{"Dentaku::AST::MemberAccess requires a hash, but got " ++ ruby_type_name(value)}

def access_value(value: Value, index: Unit -> Value) -> Value:
  match value:
    case NullValue{}:
      NullValue{}
    case Failure{e}:
      Failure{e}
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
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

def access_read(value: Value, index: Value, sensitive: Bool) -> Value:
  match index:
    case MemberIndex{member}:
      member_value(value, member, sensitive)
    case Failure{message}:
      Failure{message}
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case index:
      access_value(value, u => index)

def access_scoped(value: Value, index: Unit -> Value, sensitive: Bool) -> Value:
  match value:
    case NullValue{}:
      NullValue{}
    case Failure{message}:
      Failure{message}
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case value:
      access_read(value, index(Unit{}), sensitive)

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
    case RaisedNumeric{error_class, error_message}:
      Raised{error_class, error_message}

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
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
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
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case length:
      Failure{"Invalid string length"}

def mid_offset(offset: Value, +text: String, length: Unit -> Value) -> Value:
  match offset:
    case Number{n}:
      mid_length(named_string_count(string_count(length(Unit{}), String.length(text)), "MID", "length"), text, n)
    case Failure{message}:
      Failure{message}
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case offset:
      Failure{"Invalid string offset"}

def mid_text(value: Value, offset: Unit -> Value, length: Unit -> Value) -> Value:
  match value:
    case Failure{message}:
      Failure{message}
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case value:
      +text = ruby_render(value, False{}, False{})
      mid_offset(named_string_count(string_count(offset(Unit{}), 1n+String.length(text)), "MID", "offset"), text, length)

def contains_needle(needle: Value, haystack: String) -> Value:
  match needle:
    case Failure{message}:
      Failure{message}
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case needle:
      Logical{contains_text(haystack, ruby_render(needle, False{}, False{}))}

def contains_haystack(haystack: Value, needle: Unit -> Value) -> Value:
  match haystack:
    case Failure{message}:
      Failure{message}
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
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
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case order:
      Failure{"Invalid numeric comparison"}

def extreme_failure(a: Value, b: Value) -> Value:
  match a b:
    case FloatNumber{value} b:
      Raised{"ArgumentError", "comparison of Float with " ++ ruby_render(b, False{}, False{}) ++ " failed"}
    case a FloatNumber{value}:
      Raised{"ArgumentError", "comparison of Float with " ++ ruby_render(a, False{}, False{}) ++ " failed"}
    case a b:
      Raised{"ArgumentError", "comparison of " ++ ruby_type_name(a) ++ " with " ++ ruby_render(b, False{}, False{}) ++ " failed"}

def extreme_extended_order(order: Maybe<&2, Cmp>, is_min: Bool, a: Value, b: Value) -> Value:
  match order:
    case Some{+order}:
      Bool.pick(Value, Bool.pick(Bool, is_min, Bool.not(Cmp.is_gt(order)), Bool.not(Cmp.is_lt(order))), a, b)
    case None{}:
      extreme_failure(a, b)

def extreme_operands(a: Maybe<&2, FloatNumeric.Number>, b: Maybe<&2, FloatNumeric.Number>, is_min: Bool, original_a: Value, original_b: Value) -> Value:
  match a b:
    case Some{a} Some{b}:
      extreme_extended_order(FloatNumeric.compare(a, b), is_min, original_a, original_b)
    case a b:
      Failure{"Expected numbers"}

def extreme_dispatch(extended: Bool, is_min: Bool, +a: Value, +b: Value) -> Value:
  match extended is_min:
    case True{} is_min:
      extreme_operands(float_numeric(a), float_numeric(b), is_min, a, b)
    case False{} True{}:
      extreme_pick(compare(a, b, LessOrEqual{}), a, b)
    case False{} False{}:
      extreme_pick(compare(a, b, GreaterOrEqual{}), a, b)

def extreme_compare(is_min: Bool, +a: Value, +b: Value) -> Value:
  extreme_dispatch(Bool.or(has_extended_numeric(a), has_extended_numeric(b)), is_min, a, b)

def extreme_value(accumulator: Value, candidate: Value, is_min: Bool) -> Value:
  match accumulator candidate:
    case Failure{e} candidate:
      Failure{e}
    case Raised{error_class, error_message} candidate:
      Raised{error_class, error_message}
    case accumulator Failure{e}:
      Failure{e}
    case accumulator Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case NullValue{} candidate:
      candidate
    case accumulator NullValue{}:
      accumulator
    case accumulator candidate:
      extreme_compare(is_min, accumulator, candidate)

def abs_value(value: Value) -> Value:
  match value:
    case FloatNumber{value}:
      FloatNumber{BinaryFormat.absolute(value)}
    case DecimalNonfinite{FloatNumeric.Infinity{negative}}:
      DecimalNonfinite{FloatNumeric.Infinity{False{}}}
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

def hash_collection(nodes: List<&2, Value>) -> Bool:
  match nodes:
    case Nil{}:
      True{}
    case ArgumentValue{HashNil{}} <> rest:
      hash_collection(rest)
    case ArgumentValue{HashEntry{key, item, tail}} <> rest:
      hash_collection(rest)
    case nodes:
      False{}

def enumeration_collection(kind: EnumerationKind, +value: Value) -> Value:
  match kind:
    case PluckItems{}:
      Bool.pick(Value, hash_collection(collection_nodes(value)), value, Failure{"PLUCK() requires first argument to be an array of hashes"})
    case kind:
      value

def pluck_last(last: Maybe<&2, Value>, name: String, path: String, value: Value) -> Maybe<&2, Value>:
  match last:
    case Some{item}:
      Some{item}
    case None{}:
      Bool.pick(Maybe<&2, Value>, String.eq(name, path), Some{value}, None{})

def pluck_find(hash: Value, +path: String) -> Maybe<&2, Value>:
  match hash:
    case HashEntry{key, item, tail}:
      pluck_last(pluck_find(tail, path), ruby_render(key, False{}, False{}), path, item)
    case hash:
      None{}

def pluck_default(result: Maybe<&2, Value>, fallback: Value) -> Value:
  match result:
    case Some{item}:
      item
    case None{}:
      fallback

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

def sum_balanced(tree: Value) -> Value:
  match tree:
    case ArgumentValue{value}:
      sum_balanced(value)
    case ArrayNil{}:
      Number{0n}
    case ArrayCons{head, tail}:
      x y = sum_balanced(head) sum_balanced(tail)
      add(x, y)
    case ArgumentPair{a, b}:
      x y = sum_balanced(a) sum_balanced(b)
      add(x, y)
    case EmptyArgumentValues{}:
      Number{0n}
    case tree:
      require_numeric(tree)

def product_balanced(tree: Value) -> Value:
  match tree:
    case ArgumentValue{value}:
      product_balanced(value)
    case ArrayNil{}:
      Number{1n}
    case ArrayCons{head, tail}:
      x y = product_balanced(head) product_balanced(tail)
      multiply(x, y)
    case ArgumentPair{a, b}:
      x y = product_balanced(a) product_balanced(b)
      multiply(x, y)
    case EmptyArgumentValues{}:
      Number{1n}
    case tree:
      require_numeric(tree)

def extreme_balanced(tree: Value, +is_min: Bool) -> Value:
  match tree:
    case ArgumentValue{value}:
      extreme_balanced(value, is_min)
    case ArrayNil{}:
      NullValue{}
    case ArrayCons{head, tail}:
      x y = extreme_balanced(head, is_min) extreme_balanced(tail, is_min)
      extreme_value(x, y, is_min)
    case ArgumentPair{a, b}:
      x y = extreme_balanced(a, is_min) extreme_balanced(b, is_min)
      extreme_value(x, y, is_min)
    case EmptyArgumentValues{}:
      NullValue{}
    case tree:
      require_numeric(tree)

def reduction_node(value: Value) -> Value:
  match value:
    case ArgumentValue{value}:
      value
    case value:
      value

def extended_nodes(nodes: List<&2, Value>) -> Bool:
  match nodes:
    case Nil{}:
      False{}
    case node <> rest:
      Bool.or(has_extended_numeric(reduction_node(node)), extended_nodes(rest))

def validate_reduction_value(value: Value, next: Value -> NumericInputs) -> NumericInputs:
  match value:
    case Failure{message}:
      NumericError{Failure{message}}
    case Raised{class_name, message}:
      NumericError{Raised{class_name, message}}
    case value:
      next(value)

def validate_reduction_nodes(nodes: List<&2, Value>, reversed: List<&2, Value>) -> NumericInputs:
  match nodes:
    case Nil{}:
      NumericValues{List.reverse(&2, Value, reversed)}
    case node <> rest:
      validate_reduction_value(require_numeric(reduction_node(node)), value => validate_reduction_nodes(rest, value <> reversed))

def unchecked_operands(operation: FloatNumeric.Operation, a: Maybe<&2, FloatNumeric.Number>, b: Maybe<&2, FloatNumeric.Number>) -> Value:
  match a b:
    case Some{a} Some{b}:
      from_float_numeric(FloatNumeric.operate_unchecked(operation, a, b))
    case a b:
      Failure{"Expected numbers"}

def reduction_kind_step(kind: FunctionKind, a: Value, b: Value) -> Value:
  match kind:
    case SumFunction{}:
      unchecked_operands(FloatNumeric.Sum{}, float_numeric(a), float_numeric(b))
    case ProductFunction{}:
      unchecked_operands(FloatNumeric.Product{}, float_numeric(a), float_numeric(b))
    case MinFunction{}:
      extreme_value(a, b, True{})
    case MaxFunction{}:
      extreme_value(a, b, False{})
    case kind:
      Failure{"Invalid numeric reduction"}

def reduction_step(kind: FunctionKind, a: Value, b: Value) -> Value:
  match a b:
    case Failure{message} b:
      Failure{message}
    case Raised{class_name, message} b:
      Raised{class_name, message}
    case a b:
      reduction_kind_step(kind, a, b)

def reduction_fold(nodes: List<&2, Value>, +kind: FunctionKind, accumulator: Value) -> Value:
  match nodes:
    case Nil{}:
      accumulator
    case node <> rest:
      reduction_fold(rest, kind, reduction_step(kind, accumulator, node))

def reduction_initial(kind: FunctionKind) -> Value:
  match kind:
    case SumFunction{}:
      Number{0n}
    case ProductFunction{}:
      Number{1n}
    case kind:
      NullValue{}

def reduction_validated(values: NumericInputs, +kind: FunctionKind) -> Value:
  match values:
    case NumericValues{nodes}:
      reduction_fold(nodes, kind, reduction_initial(kind))
    case NumericError{value}:
      value

# Argument evaluation stays balanced. Float reductions follow Ruby's dependent
# left fold: rounding and mixed coercion make reassociation observable.
def reduction_dispatch(extended: Bool, kind: FunctionKind, nodes: List<&2, Value>, tree: Value) -> Value:
  match extended kind:
    case True{} kind:
      reduction_validated(validate_reduction_nodes(nodes, Nil{}), kind)
    case False{} SumFunction{}:
      sum_balanced(tree)
    case False{} ProductFunction{}:
      product_balanced(tree)
    case False{} MinFunction{}:
      extreme_balanced(tree, True{})
    case False{} MaxFunction{}:
      extreme_balanced(tree, False{})
    case False{} kind:
      Failure{"Invalid numeric reduction"}

def numeric_reduction(kind: FunctionKind, +tree: Value) -> Value:
  +nodes = numeric_nodes(tree)
  reduction_dispatch(extended_nodes(nodes), kind, nodes, tree)

def sum_tree(tree: Value) -> Value:
  numeric_reduction(SumFunction{}, tree)

def product_tree(tree: Value) -> Value:
  numeric_reduction(ProductFunction{}, tree)

def extreme_tree(tree: Value, is_min: Bool) -> Value:
  numeric_reduction(Bool.pick(FunctionKind, is_min, MinFunction{}, MaxFunction{}), tree)

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
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case value:
      next(value)

def case_when_value(key: Value, subject: Value, yes: Unit -> Value, no: Unit -> Value) -> Value:
  match key:
    case Failure{message}:
      Failure{message}
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
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

def percentage_value(value: Value) -> Value:
  unchecked_operands(FloatNumeric.Product{}, float_numeric(value), Some{FloatNumeric.Floating{Binary.from_words(1065646817, 1202590843)}})

def percentage(value: Value) -> Value:
  with_value(cast_numeric(value), value => percentage_value(value))

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
    case Modulo{a, b}:
      Modulo{prepare_expression(a), prepare_expression(b)}
    case Bitwise{kind, a, b}:
      Bitwise{kind, prepare_expression(a), prepare_expression(b)}
    case If{condition, yes, no}:
      If{prepare_expression(condition), prepare_expression(yes), prepare_expression(no)}
    case Not{a}:
      Not{prepare_expression(a)}
    case Negate{a}:
      Negate{prepare_expression(a)}
    case Percentage{a}:
      Percentage{prepare_expression(a)}
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
    case PluckItems{} mapped:
      ArgumentValue{mapped}
    case MapItems{} mapped:
      ArgumentValue{mapped}
    case kind Failure{message}:
      Failure{message}
    case kind Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case FilterItems{} mapped:
      Bool.pick(Value, truthy(mapped), ArgumentValue{item}, EmptyArgumentValues{})
    case AllItems{} mapped:
      Logical{truthy(mapped)}
    case AnyItems{} mapped:
      Logical{truthy(mapped)}

def filter_leaf(item: Value, mapped: Value) -> Value:
  match mapped:
    case Raised{class_name, message}:
      ArgumentValue{Raised{class_name, message}}
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
    case Raised{error_class, error_message}:
      Raised{error_class, error_message}
    case Logical{+b}:
      logical_chosen(Cmp.is_eq(Bool.cmp(b, decisive_value)), Logical{b}, next)
    case left:
      Failure{"Invalid enumeration predicate"}

def enumeration_finish(kind: EnumerationKind, result: Value) -> Value:
  match kind:
    case PluckItems{}:
      array_value(result)
    case MapItems{}:
      array_value(result)
    case FilterItems{}:
      array_value(result)
    case kind:
      result

# Recursion is lexicographic over expression and batch. An enum enters its body
# subexpression with a fresh batch; each repeated body evaluation consumes a
# smaller batch node. Context and mode can then change without unsafe recursion.
def resolve_lookup(context: List<&2, Binding>, name: String, sensitive: Bool, subjects: List<&2, Value>) -> Value:
  lookup(context, name, sensitive)

# The resolver is compiled into each evaluator specialization. The ordinary
# evaluator retains its total lookup; a stored-expression runner can share the
# traversal without imposing a fixed recursion cutoff on user programs.
def evaluate_using(~resolve: List<&2, Binding> -> String -> Bool -> List<&2, Value> -> Value, e: Expr, +batch: Value, +context: List<&2, Binding>, +sensitive: Bool, +subjects: List<&2, Value>, mode: EvaluationMode) -> Value:
  match e batch mode:
    case +e ArgumentPair{a, b} EvaluateItems{AllItems{}, +binder}:
      enumeration_decide(evaluate_using(~resolve, e, a, context, sensitive, subjects, EvaluateItems{AllItems{}, binder}), False{}, u => evaluate_using(~resolve, e, b, context, sensitive, subjects, EvaluateItems{AllItems{}, binder}))
    case +e ArgumentPair{a, b} EvaluateItems{AnyItems{}, +binder}:
      enumeration_decide(evaluate_using(~resolve, e, a, context, sensitive, subjects, EvaluateItems{AnyItems{}, binder}), True{}, u => evaluate_using(~resolve, e, b, context, sensitive, subjects, EvaluateItems{AnyItems{}, binder}))
    case +e ArgumentPair{a, b} EvaluateItems{+kind, +binder}:
      x y = evaluate_using(~resolve, e, a, context, sensitive, subjects, EvaluateItems{kind, binder}) evaluate_using(~resolve, e, b, context, sensitive, subjects, EvaluateItems{kind, binder})
      ArgumentPair{x, y}
    case +e ArgumentValue{item} EvaluateItems{PluckItems{}, binder}:
      ArgumentValue{with_value(evaluate_using(~resolve, e, item, context, sensitive, subjects, EvaluateOne{}), fallback => pluck_default(pluck_find(item, normalize(sensitive, binder)), fallback))}
    case +e ArgumentValue{+item} EvaluateItems{FilterItems{}, binder}:
      filter_leaf(item, evaluate_using(~resolve, e, item, item_context(binder, item, context, sensitive), sensitive, subjects, EvaluateOne{}))
    case +e ArgumentValue{+item} EvaluateItems{kind, binder}:
      enumeration_leaf(kind, item, mapped_result(lookup(context, "__evaluation_mode", sensitive), evaluate_using(~resolve, e, item, item_context(binder, item, context, sensitive), sensitive, subjects, EvaluateOne{})))
    case e EmptyArgumentValues{} EvaluateItems{kind, binder}:
      enumeration_empty(kind)
    case +e ArgumentPair{a, b} EvaluateReduction{+memo_binder, +item_binder, memo}:
      with_value(evaluate_using(~resolve, e, a, context, sensitive, subjects, EvaluateReduction{memo_binder, item_binder, memo}), next => evaluate_using(~resolve, e, b, context, sensitive, subjects, EvaluateReduction{memo_binder, item_binder, next}))
    case +e ArgumentValue{+item} EvaluateReduction{memo_binder, item_binder, memo}:
      evaluate_using(~resolve, e, item, item_context(item_binder, item, item_context(memo_binder, memo, context, sensitive), sensitive), sensitive, subjects, EvaluateOne{})
    case e EmptyArgumentValues{} EvaluateReduction{memo_binder, item_binder, memo}:
      memo
    case EnumerationExpression{+kind, collection, binder, body} batch EvaluateOne{}:
      with_value(evaluate_using(~resolve, collection, batch, context, sensitive, subjects, EvaluateOne{}), value => with_value(enumeration_collection(kind, value), values => enumeration_finish(kind, evaluate_using(~resolve, body, collection_batch(values), context, sensitive, subjects, EvaluateItems{kind, binder}))))
    case ReductionExpression{collection, memo_binder, item_binder, body, initial} batch EvaluateOne{}:
      with_value(evaluate_using(~resolve, collection, batch, context, sensitive, subjects, EvaluateOne{}), values => with_value(evaluate_using(~resolve, initial, batch, context, sensitive, subjects, EvaluateOne{}), memo => evaluate_using(~resolve, body, collection_batch(values), context, sensitive, subjects, EvaluateReduction{memo_binder, item_binder, memo})))
    case CaseExpression{subject, clauses} batch EvaluateOne{}:
      with_case_value(evaluate_using(~resolve, subject, batch, context, sensitive, subjects, EvaluateOne{}), value => evaluate_using(~resolve, clauses, batch, context, sensitive, value <> subjects, EvaluateOne{}))
    case WhenExpression{key, value, rest} batch EvaluateOne{}:
      case_when_value(evaluate_using(~resolve, key, batch, context, sensitive, subjects, EvaluateOne{}), case_subject(subjects), u => evaluate_using(~resolve, value, batch, context, sensitive, subjects, EvaluateOne{}), u => evaluate_using(~resolve, rest, batch, context, sensitive, subjects, EvaluateOne{}))
    case ElseExpression{value} batch EvaluateOne{}:
      evaluate_using(~resolve, value, batch, context, sensitive, subjects, EvaluateOne{})
    case NoCaseMatch{} batch EvaluateOne{}:
      Failure{"No block matched the switch value '" ++ ruby_render(case_subject(subjects), False{}, False{}) ++ "'"}
    case MidExpression{value, offset, length} batch EvaluateOne{}:
      mid_text(evaluate_using(~resolve, value, batch, context, sensitive, subjects, EvaluateOne{}), u => evaluate_using(~resolve, offset, batch, context, sensitive, subjects, EvaluateOne{}), u => evaluate_using(~resolve, length, batch, context, sensitive, subjects, EvaluateOne{}))
    case ContainsExpression{needle, haystack} batch EvaluateOne{}:
      contains_haystack(evaluate_using(~resolve, haystack, batch, context, sensitive, subjects, EvaluateOne{}), u => evaluate_using(~resolve, needle, batch, context, sensitive, subjects, EvaluateOne{}))
    case ArrayLiteral{elements} batch EvaluateOne{}:
      array_value(evaluate_using(~resolve, elements, batch, context, sensitive, subjects, EvaluateOne{}))
    case Access{structure, index} batch EvaluateOne{}:
      access_scoped(evaluate_using(~resolve, structure, batch, context, sensitive, subjects, EvaluateOne{}), u => evaluate_using(~resolve, index, batch, context, sensitive, subjects, EvaluateOne{}), sensitive)
    case CountOneExpression{a} batch EvaluateOne{}:
      count_single(evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}))
    case CountManyExpression{arguments, count} batch EvaluateOne{}:
      Number{count}
    case EmptyArguments{} batch EvaluateOne{}:
      EmptyArgumentValues{}
    case Argument{a, validation} batch EvaluateOne{}:
      ArgumentValue{validate_argument(validation, evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}))}
    case Arguments{a, b} batch EvaluateOne{}:
      x y = evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}) evaluate_using(~resolve, b, batch, context, sensitive, subjects, EvaluateOne{})
      ArgumentPair{x, y}
    case FunctionCall{kind, arguments} batch EvaluateOne{}:
      call(kind, evaluate_using(~resolve, arguments, batch, context, sensitive, subjects, EvaluateOne{}))
    case Literal{v} batch EvaluateOne{}:
      v
    case Variable{name} batch EvaluateOne{}:
      resolve(context, name, sensitive, subjects)
    case Add{a, b} batch EvaluateOne{}:
      x y = evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}) evaluate_using(~resolve, b, batch, context, sensitive, subjects, EvaluateOne{})
      add(x, y)
    case Divide{a, b} batch EvaluateOne{}:
      decimal_right_value(DecimalDivide{}, evaluate_using(~resolve, b, batch, context, sensitive, subjects, EvaluateOne{}), u => evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}))
    case Modulo{a, b} batch EvaluateOne{}:
      decimal_right_value(DecimalModulo{}, evaluate_using(~resolve, b, batch, context, sensitive, subjects, EvaluateOne{}), u => evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}))
    case Bitwise{kind, a, b} batch EvaluateOne{}:
      with_value(evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}), left => with_value(evaluate_using(~resolve, b, batch, context, sensitive, subjects, EvaluateOne{}), right => bitwise(kind, left, right)))
    case Multiply{a, b} batch EvaluateOne{}:
      x y = evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}) evaluate_using(~resolve, b, batch, context, sensitive, subjects, EvaluateOne{})
      multiply(x, y)
    case And{a, b} batch EvaluateOne{}:
      logical_left(evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}), True{}, u => evaluate_using(~resolve, b, batch, context, sensitive, subjects, EvaluateOne{}))
    case Or{a, b} batch EvaluateOne{}:
      logical_left(evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}), False{}, u => evaluate_using(~resolve, b, batch, context, sensitive, subjects, EvaluateOne{}))
    case Xor{a, b} batch EvaluateOne{}:
      x y = evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}) evaluate_using(~resolve, b, batch, context, sensitive, subjects, EvaluateOne{})
      logical_xor(x, y)
    case PrefixNot{a} batch EvaluateOne{}:
      logical_not(evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}))
    case CoerceNumber{a} batch EvaluateOne{}:
      require_numeric(evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}))
    case Compare{op, a, b} batch EvaluateOne{}:
      x y = evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}) evaluate_using(~resolve, b, batch, context, sensitive, subjects, EvaluateOne{})
      compare(x, y, op)
    case Round{a, places, mode} batch EvaluateOne{}:
      x p = evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}) evaluate_using(~resolve, places, batch, context, sensitive, subjects, EvaluateOne{})
      round(x, p, mode)
    case Negate{a} batch EvaluateOne{}:
      negate(evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}))
    case Percentage{a} batch EvaluateOne{}:
      percentage(evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}))
    case Subtract{a, b} batch EvaluateOne{}:
      x y = evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}) evaluate_using(~resolve, b, batch, context, sensitive, subjects, EvaluateOne{})
      subtract(x, y)
    case Not{a} batch EvaluateOne{}:
      logical_not(evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}))
    case If{c, a, b} batch EvaluateOne{}:
      choose(evaluate_using(~resolve, c, batch, context, sensitive, subjects, EvaluateOne{}), u => evaluate_using(~resolve, a, batch, context, sensitive, subjects, EvaluateOne{}), u => evaluate_using(~resolve, b, batch, context, sensitive, subjects, EvaluateOne{}))
    case e batch mode:
      Failure{"Invalid evaluation batch"}

def evaluate_machine(e: Expr, +batch: Value, +context: List<&2, Binding>, +sensitive: Bool, +subjects: List<&2, Value>, mode: EvaluationMode) -> Value:
  evaluate_using(~resolve_lookup, e, batch, context, sensitive, subjects, mode)

def evaluate_scoped(e: Expr, context: List<&2, Binding>, sensitive: Bool, subjects: List<&2, Value>) -> Value:
  evaluate_machine(prepare_expression(e), EmptyArgumentValues{}, context, sensitive, subjects, EvaluateOne{})

def evaluate_in(e: Expr, context: List<&2, Binding>, sensitive: Bool) -> Value:
  evaluate_scoped(e, context, sensitive, Nil{})

def evaluate(e: Expr) -> Value:
  evaluate_in(e, Nil{}, False{})

def show(value: Value) -> String:
  match value:
    case Raised{class_name, message}:
      message
    case FloatNumber{value}:
      BinaryFormat.show(value)
    case DecimalNonfinite{value}:
      FloatNumeric.special_text(value)
    case StoredExpression{expression, sensitive}:
      "AST"
    case MemberIndex{name}:
      "Internal member index"
    case SymbolValue{s}:
      s
    case NamedReference{kind, name, ancestors}:
      name
    case RangeValue{first, last, excluded}:
      ruby_render(RangeValue{first, last, excluded}, False{}, False{})
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
  Bool.pick(String, is_unbound_message(message), "error:Dentaku::UnboundVariableError", Bool.pick(String, String.eq(message, "Division by zero"), "error:Dentaku::ZeroDivisionError", Bool.pick(String, is_range_message(message), "error:RangeError", "error:Dentaku::ArgumentError")))

def named_snapshot(kind: ReferenceKind, name: String) -> String:
  match kind:
    case ClassReferenceKind{}:
      "class-reference:" ++ name
    case ModuleReferenceKind{}:
      "module-reference:" ++ name

def snapshot_render(value: Value, +tail_mode: Bool) -> String:
  match value:
    case Raised{class_name, message}:
      "error:" ++ class_name
    case FloatNumber{value}:
      "float:" ++ Binary.snapshot(value)
    case DecimalNonfinite{value}:
      "number:" ++ FloatNumeric.special_text(value)
    case StoredExpression{expression, sensitive}:
      "ast"
    case MemberIndex{name}:
      "internal:member-index"
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
    case NamedReference{kind, name, ancestors}:
      named_snapshot(kind, name)
    case RangeValue{first, last, excluded}:
      +a = snapshot_render(first, False{})
      +b = snapshot_render(last, False{})
      "range:" ++ Bool.pick(String, excluded, "exclusive:", "inclusive:") ++ Nat.show(String.length(a)) ++ ":" ++ a ++ Nat.show(String.length(b)) ++ ":" ++ b
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
    case Raised{class_name, message}:
      "error:" ++ class_name
    case FloatNumber{value}:
      "class:Float"
    case DecimalNonfinite{value}:
      "class:BigDecimal"
    case SymbolValue{s}:
      "class:Symbol"
    case NamedReference{kind, name, ancestors}:
      "class:" ++ reference_type_name(kind)
    case RangeValue{first, last, excluded}:
      "class:Range"
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
    case Raised{class_name, message}:
      "message:" ++ message
    case Failure{+message}:
      "message:" ++ Bool.pick(String, String.eq(message, "Division by zero"), "Dentaku::ZeroDivisionError", message)
    case value:
      "no-error"
