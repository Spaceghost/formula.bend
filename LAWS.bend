import Base
import ./src/core.bend as Core
import ./src/decimal.bend as Decimal
import ./src/division.bend as Division

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
