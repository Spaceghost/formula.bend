import Base
import ./src/core.bend as Core
import ./src/decimal.bend as Decimal
import ./LAWS.bend as Laws
import ./src/bits.bend as Bits

def Laws.bitwise_left_error(kind, message, right):
  match kind:
    case Bits.BitOr{}:
      {==}
    case Bits.BitAnd{}:
      {==}
    case Bits.ShiftLeft{}:
      {==}
    case Bits.ShiftRight{}:
      {==}

def Laws.bitwise_right_error(kind, left, message):
  match kind:
    case Bits.BitOr{}:
      {==}
    case Bits.BitAnd{}:
      {==}
    case Bits.ShiftLeft{}:
      {==}
    case Bits.ShiftRight{}:
      {==}

def Laws.bitwise_false_and_eager(message):
  {==}

def Laws.empty_hash_read(key):
  {==}

def Laws.member_null(name, sensitive):
  {==}

def Laws.member_error(message, name, sensitive):
  {==}

def Laws.modulo_zero_divisor(left):
  {==}

def Laws.modulo_right_zero_skips_left(left):
  {==}

def Laws.modulo_right_failure(left, message):
  {==}

def Laws.empty_comment_prefix(source):
  {==}

def Laws.empty_formula(context, sensitive):
  {==}

def Laws.strict_item_error(message):
  {==}

def Laws.permissive_item_error(message):
  {==}

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

def Laws.null_access_skips_index(index):
  {==}

def Laws.count_pair_skips_values(left, right):
  {==}

def Laws.array_head_access(head, tail):
  {==}

def Laws.canonical_zero(scale):
  {==}

def Laws.numeric_string_leading_space(text):
  {==}

def Laws.mid_invalid_offset_skips_length(length):
  {==}

def Laws.contains_haystack_error_first(needle, message):
  {==}

def Laws.signed_zero_divisor(numerator, scale):
  {==}

def Laws.signed_zero_array_equality(left_scale, right_scale):
  {==}

def Laws.case_switch_error_first(message, clauses):
  {==}

def Laws.case_first_true_branch(yes, rest, context, sensitive, subjects):
  {==}

def Laws.all_skips_later_predicate(later):
  {==}

def Laws.any_skips_later_predicate(later):
  {==}

# Splitting the expression datatype proves an empty batch never enters its body.
def Laws.empty_enumeration_batch(body, kind, binder, context, sensitive, subjects):
  match body:
    case Core.Literal{x0}:
      {==}
    case Core.Variable{x0}:
      {==}
    case Core.Add{x0, x1}:
      {==}
    case Core.Multiply{x0, x1}:
      {==}
    case Core.Divide{x0, x1}:
      {==}
    case Core.Modulo{x0, x1}:
      {==}
    case Core.Bitwise{x0, x1, x2}:
      {==}
    case Core.If{x0, x1, x2}:
      {==}
    case Core.Not{x0}:
      {==}
    case Core.Negate{x0}:
      {==}
    case Core.Subtract{x0, x1}:
      {==}
    case Core.Round{x0, x1, x2}:
      {==}
    case Core.Compare{x0, x1, x2}:
      {==}
    case Core.CoerceNumber{x0}:
      {==}
    case Core.And{x0, x1}:
      {==}
    case Core.Or{x0, x1}:
      {==}
    case Core.Xor{x0, x1}:
      {==}
    case Core.PrefixNot{x0}:
      {==}
    case Core.Argument{x0, x1}:
      {==}
    case Core.Arguments{x0, x1}:
      {==}
    case Core.EmptyArguments{}:
      {==}
    case Core.FunctionCall{x0, x1}:
      {==}
    case Core.ArrayLiteral{x0}:
      {==}
    case Core.Access{x0, x1}:
      {==}
    case Core.CaseExpression{x0, x1}:
      {==}
    case Core.WhenExpression{x0, x1, x2}:
      {==}
    case Core.ElseExpression{x0}:
      {==}
    case Core.NoCaseMatch{}:
      {==}
    case Core.EnumerationExpression{x0, x1, x2, x3}:
      {==}
    case Core.ReductionExpression{x0, x1, x2, x3, x4}:
      {==}
    case Core.MidExpression{x0, x1, x2}:
      {==}
    case Core.ContainsExpression{x0, x1}:
      {==}
    case Core.CountOneExpression{x0}:
      {==}
    case Core.CountManyExpression{x0, x1}:
      {==}

def Laws.empty_reduction_batch(body, memo_name, item_name, initial, context, sensitive, subjects):
  match body:
    case Core.Literal{x0}:
      {==}
    case Core.Variable{x0}:
      {==}
    case Core.Add{x0, x1}:
      {==}
    case Core.Multiply{x0, x1}:
      {==}
    case Core.Divide{x0, x1}:
      {==}
    case Core.Modulo{x0, x1}:
      {==}
    case Core.Bitwise{x0, x1, x2}:
      {==}
    case Core.If{x0, x1, x2}:
      {==}
    case Core.Not{x0}:
      {==}
    case Core.Negate{x0}:
      {==}
    case Core.Subtract{x0, x1}:
      {==}
    case Core.Round{x0, x1, x2}:
      {==}
    case Core.Compare{x0, x1, x2}:
      {==}
    case Core.CoerceNumber{x0}:
      {==}
    case Core.And{x0, x1}:
      {==}
    case Core.Or{x0, x1}:
      {==}
    case Core.Xor{x0, x1}:
      {==}
    case Core.PrefixNot{x0}:
      {==}
    case Core.Argument{x0, x1}:
      {==}
    case Core.Arguments{x0, x1}:
      {==}
    case Core.EmptyArguments{}:
      {==}
    case Core.FunctionCall{x0, x1}:
      {==}
    case Core.ArrayLiteral{x0}:
      {==}
    case Core.Access{x0, x1}:
      {==}
    case Core.CaseExpression{x0, x1}:
      {==}
    case Core.WhenExpression{x0, x1, x2}:
      {==}
    case Core.ElseExpression{x0}:
      {==}
    case Core.NoCaseMatch{}:
      {==}
    case Core.EnumerationExpression{x0, x1, x2, x3}:
      {==}
    case Core.ReductionExpression{x0, x1, x2, x3, x4}:
      {==}
    case Core.MidExpression{x0, x1, x2}:
      {==}
    case Core.ContainsExpression{x0, x1}:
      {==}
    case Core.CountOneExpression{x0}:
      {==}
    case Core.CountManyExpression{x0, x1}:
      {==}
