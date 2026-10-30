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
    case accumulator candidate:
      extreme_compare(is_min, accumulator, candidate)

def abs_value(value: Value) -> Value:
  match value:
    case NegativeNumber{n}:
      compact(n)
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
      require_numeric(value)
    case ArgumentPair{a, b}:
      x y = sum_tree(a) sum_tree(b)
      add(x, y)
    case EmptyArgumentValues{}:
      Number{0n}
    case tree:
      Failure{"Invalid argument tree"}

def product_tree(tree: Value) -> Value:
  match tree:
    case ArgumentValue{value}:
      require_numeric(value)
    case ArgumentPair{a, b}:
      x y = product_tree(a) product_tree(b)
      multiply(x, y)
    case EmptyArgumentValues{}:
      Number{1n}
    case tree:
      Failure{"Invalid argument tree"}

def extreme_tree(tree: Value, +is_min: Bool) -> Value:
  match tree:
    case ArgumentValue{value}:
      require_numeric(value)
    case ArgumentPair{a, b}:
      x y = extreme_tree(a, is_min) extreme_tree(b, is_min)
      extreme_value(x, y, is_min)
    case EmptyArgumentValues{}:
      NullValue{}
    case tree:
      Failure{"Invalid argument tree"}

def function_arguments(kind: FunctionKind, tree: Value) -> Value:
  match kind:
    case ProductFunction{}:
      product_tree(tree)
    case MinFunction{}:
      extreme_tree(tree, True{})
    case MaxFunction{}:
      extreme_tree(tree, False{})
    case AverageFunction{}:
      +arguments = tree
      divide(sum_tree(arguments), Number{argument_count(arguments)})
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
  Bool.pick(String, String.starts_with(message, "Unbound variable: "), "error:Dentaku::UnboundVariableError", Bool.pick(String, String.eq(message, "Division by zero"), "error:Dentaku::ZeroDivisionError", "error:Dentaku::ArgumentError"))

def snapshot(value: Value) -> String:
  match value:
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
