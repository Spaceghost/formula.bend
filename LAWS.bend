import Base
import ./src/core.bend as Core

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
