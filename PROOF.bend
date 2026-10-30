import Base
import ./src/core.bend as Core
import ./src/decimal.bend as Decimal
import ./LAWS.bend as Laws

def Laws.true_branch(yes, no):
  {==}

def Laws.false_branch(yes, no):
  {==}

def Laws.literal(value):
  {==}

def Laws.absolute_axis(coordinate, delta):
  {==}

def Laws.mixed_row_anchor(row, column, rows, columns):
  {==}

def Laws.bound_literal(value, context, sensitive):
  {==}

def Laws.product_scale(x, y, sx, sy):
  {==}

def Laws.subtraction_left_error(message, right):
  {==}

def Laws.rounding_failure(message, places, mode):
  {==}

def Laws.division_by_zero(numerator, places):
  match numerator:
    case Decimal.Exact{digits, s}:
      {==}

def Laws.fixed_axis_origin(index, origin_a, origin_b, limit):
  {==}

def Laws.null_branch(yes, no):
  {==}

def Laws.numeric_guard_truthy(n, yes, no):
  {==}

def Laws.and_false_short_circuit(right):
  {==}

def Laws.or_true_short_circuit(right):
  {==}

def Laws.argument_error_left(message, right):
  {==}

def Laws.sum_dependency_duplicates(name, sensitive):
  {==}
