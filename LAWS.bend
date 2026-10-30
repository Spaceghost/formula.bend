import Base
import ./src/core.bend as Core
import ./src/decimal.bend as Decimal
import ./src/division.bend as Division
import ./src/address.bend as Address
import ./src/dependencies.bend as Dependencies

import ./src/reference.bend as Ref
# Initial project contracts. Changes must retain or strengthen their guarantees.
law true_branch:
  for +yes: Core.Expr
  for no: Core.Expr
  {Core.evaluate(Core.If{Core.Literal{Core.Logical{True{}}}, yes, no}) == Core.evaluate(yes) : Core.Value}

law false_branch:
  for yes: Core.Expr
  for +no: Core.Expr
  {Core.evaluate(Core.If{Core.Literal{Core.Logical{False{}}}, yes, no}) == Core.evaluate(no) : Core.Value}

law literal:
  for +value: Core.Value
  {Core.evaluate(Core.Literal{value}) == value : Core.Value}


law absolute_axis:
  for +coordinate: Nat
  for delta: Nat
  {Ref.shift_axis(Ref.Absolute{coordinate}, delta) == Ref.Absolute{coordinate} : Ref.Axis}

law mixed_row_anchor:
  for +row: Nat
  for column: Nat
  for rows: Nat
  for columns: Nat
  {Ref.copy_forward(Ref.Cell{Ref.Absolute{row}, Ref.Relative{column}}, rows, columns) == Ref.Cell{Ref.Absolute{row}, Ref.Relative{Nat.add(column, columns)}} : Ref.Reference}

law bound_literal:
  for +value: Core.Value
  for context: List<&2, Core.Binding>
  for sensitive: Bool
  {Core.evaluate_in(Core.Literal{value}, context, sensitive) == value : Core.Value}

law product_scale:
  for x: List<&2, U32>
  for y: List<&2, U32>
  for +sx: Nat
  for +sy: Nat
  {Decimal.scale(Decimal.multiply(Decimal.Exact{x, sx}, Decimal.Exact{y, sy})) == Nat.add(sx, sy) : Nat}

law subtraction_left_error:
  for +message: String
  for right: Core.Value
  {Core.subtract(Core.Failure{message}, right) == Core.Failure{message} : Core.Value}

law rounding_failure:
  for +message: String
  for places: Nat
  for mode: Decimal.Rounding
  {Core.round(Core.Failure{message}, Core.Number{places}, mode) == Core.Failure{message} : Core.Value}

law division_by_zero:
  for numerator: Decimal.Decimal
  for places: Nat
  {Division.divide(numerator, Decimal.Exact{Nil{}, 0n}, places) == Division.DivisionByZero{} : Division.DivisionResult}

law fixed_axis_origin:
  for +index: Nat
  for origin_a: Nat
  for origin_b: Nat
  for +limit: Nat
  {Address.resolve_axis(Address.Fixed{index}, origin_a, limit) == Address.resolve_axis(Address.Fixed{index}, origin_b, limit) : Maybe<&2, Nat>}

law null_branch:
  for yes: Core.Expr
  for +no: Core.Expr
  {Core.evaluate(Core.If{Core.Literal{Core.NullValue{}}, yes, no}) == Core.evaluate(no) : Core.Value}

law numeric_guard_truthy:
  for n: Nat
  for +yes: Core.Expr
  for no: Core.Expr
  {Core.evaluate(Core.If{Core.Literal{Core.Number{n}}, yes, no}) == Core.evaluate(yes) : Core.Value}

law and_false_short_circuit:
  for right: Core.Expr
  {Core.evaluate(Core.And{Core.Literal{Core.Logical{False{}}}, right}) == Core.Logical{False{}} : Core.Value}

law or_true_short_circuit:
  for right: Core.Expr
  {Core.evaluate(Core.Or{Core.Literal{Core.Logical{True{}}}, right}) == Core.Logical{True{}} : Core.Value}

law argument_error_left:
  for +message: String
  for right: Core.Value
  {Core.first_argument_error(Core.ArgumentPair{Core.ArgumentValue{Core.Failure{message}}, right}) == Some{Core.Failure{message}} : Maybe<&2, Core.Value>}

law sum_dependency_duplicates:
  for +name: String
  for +sensitive: Bool
  {Dependencies.analyze(Core.FunctionCall{Core.SumFunction{}, Core.Arguments{Core.Argument{Core.Variable{name}, Core.RawArgument{}}, Core.Argument{Core.Variable{name}, Core.RawArgument{}}}}, Nil{}, sensitive, False{}) == [Core.normalize(sensitive, name), Core.normalize(sensitive, name)] : List<&2, String>}

law null_access_skips_index:
  for index: Core.Expr
  {Core.evaluate(Core.Access{Core.Literal{Core.NullValue{}}, index}) == Core.NullValue{} : Core.Value}

law count_pair_skips_values:
  for left: Core.Expr
  for right: Core.Expr
  {Core.evaluate(Core.FunctionCall{Core.CountFunction{}, Core.Arguments{Core.Argument{left, Core.RawArgument{}}, Core.Argument{right, Core.RawArgument{}}}}) == Core.Number{2n} : Core.Value}

law array_head_access:
  for +head: Core.Value
  for tail: Core.Value
  {Core.array_at(Core.ArrayCons{head, tail}, 0n) == head : Core.Value}

law canonical_zero:
  for scale: Nat
  {Decimal.canonical(Decimal.Exact{Nil{}, scale}) == Decimal.Exact{Nil{}, 0n} : Decimal.Decimal}

law numeric_string_leading_space:
  for +text: String
  {Core.cast_numeric(Core.TextValue{" " ++ text}) == Core.TextValue{" " ++ text} : Core.Value}

law mid_invalid_offset_skips_length:
  for length: Core.Expr
  {Core.evaluate(Core.FunctionCall{Core.MidFunction{}, Core.Arguments{Core.Arguments{Core.Argument{Core.Literal{Core.TextValue{"abc"}}, Core.RawArgument{}}, Core.Argument{Core.Literal{Core.NegativeInteger{Decimal.Exact{[1], 0n}}}, Core.RawArgument{}}}, Core.Argument{length, Core.RawArgument{}}}}) == Core.Failure{"MID() requires offset to be positive"} : Core.Value}

law contains_haystack_error_first:
  for needle: Core.Expr
  for +message: String
  {Core.evaluate(Core.FunctionCall{Core.ContainsFunction{}, Core.Arguments{Core.Argument{needle, Core.RawArgument{}}, Core.Argument{Core.Literal{Core.Failure{message}}, Core.RawArgument{}}}}) == Core.Failure{message} : Core.Value}

law signed_zero_divisor:
  for numerator: Core.Value
  for scale: Nat
  {Core.divide(numerator, Core.NegativeNumber{Decimal.Exact{Nil{}, scale}}) == Core.Failure{"Division by zero"} : Core.Value}

law signed_zero_array_equality:
  for left_scale: Nat
  for right_scale: Nat
  {Core.value_equal(Core.ArrayCons{Core.NegativeNumber{Decimal.Exact{Nil{}, left_scale}}, Core.ArrayNil{}}, Core.ArrayCons{Core.DecimalNumber{Decimal.Exact{Nil{}, right_scale}}, Core.ArrayNil{}}, False{}) == True{} : Bool}

law case_switch_error_first:
  for +message: String
  for clauses: Core.Expr
  {Core.evaluate(Core.CaseExpression{Core.Literal{Core.Failure{message}}, clauses}) == Core.Failure{message} : Core.Value}

law case_first_true_branch:
  for +yes: Core.Expr
  for rest: Core.Expr
  for +context: List<&2, Core.Binding>
  for +sensitive: Bool
  for +subjects: List<&2, Core.Value>
  {Core.evaluate_scoped(Core.CaseExpression{Core.Literal{Core.Logical{True{}}}, Core.WhenExpression{Core.Literal{Core.Logical{True{}}}, yes, rest}}, context, sensitive, subjects) == Core.evaluate_scoped(yes, context, sensitive, Core.Logical{True{}} <> subjects) : Core.Value}
