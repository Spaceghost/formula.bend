import ./src/token_matcher.bend as Matcher
import Base
import ./src/token.bend as Token
import ./compat/corpus-wire.bend as Wire
import ./src/core.bend as Core
import ./src/decimal.bend as Decimal
import ./src/division.bend as Division
import ./src/address.bend as Address
import ./src/dependencies.bend as Dependencies
import ./src/comments.bend as Comments
import ./src/parser.bend as Parser
import ./src/bits.bend as Bits
import ./src/resolver.bend as Resolver

import ./src/reference.bend as Ref
import ./src/error_types.bend as ErrorTypes
import ./src/errors.bend as Errors

law range_zero_blocks:
  for depth: Nat
  for first: Core.Value
  for stride: Core.Value
  for last: Core.Value
  for excluded: Bool
  {Errors.range_block(depth, 0n, first, stride, last, excluded) == Core.ArrayNil{} : Core.Value}

law endless_range_array:
  for first: Core.Value
  for excluded: Bool
  {Errors.as_array(Core.RangeValue{first, Core.NullValue{}, excluded}) == Core.Failure{"cannot convert endless range to an array"} : Core.Value}

law beginless_integer_range_array:
  for last: Nat
  for excluded: Bool
  {Errors.as_array(Core.RangeValue{Core.NullValue{}, Core.Number{last}, excluded}) == Core.Failure{"can't iterate from NilClass"} : Core.Value}

law range_type_name:
  for first: Core.Value
  for last: Core.Value
  for excluded: Bool
  {Core.ruby_type_name(Core.RangeValue{first, last, excluded}) == "Range" : String}

law range_truthy:
  for first: Core.Value
  for last: Core.Value
  for excluded: Bool
  {Core.truthy(Core.RangeValue{first, last, excluded}) == True{} : Bool}

law endless_arity:
  for +first: Core.Value
  for excluded: Bool
  {Errors.expected_count(Core.RangeValue{first, Core.NullValue{}, excluded}) == "at least " ++ Errors.render(first) : String}

law named_class_type:
  for name: String
  for parents: List<&2, String>
  {Core.ruby_type_name(Core.NamedReference{Core.ClassReferenceKind{}, name, parents}) == "Class" : String}

law named_module_type:
  for name: String
  for parents: List<&2, String>
  {Core.ruby_type_name(Core.NamedReference{Core.ModuleReferenceKind{}, name, parents}) == "Module" : String}

law named_reference_truthy:
  for kind: Core.ReferenceKind
  for name: String
  for parents: List<&2, String>
  {Core.truthy(Core.NamedReference{kind, name, parents}) == True{} : Bool}

law named_relation_unrelated:
  for inclusive: Bool
  {Core.named_relation(False{}, False{}, False{}, inclusive) == Core.NullValue{} : Core.Value}

law named_relation_reflexive:
  for +inclusive: Bool
  {Core.named_relation(True{}, False{}, False{}, inclusive) == Core.Logical{inclusive} : Core.Value}

law error_override_message:
  for error: ErrorTypes.Description<Core.Value>
  for +message: String
  {ErrorTypes.message(Core.Value, ErrorTypes.with_message(Core.Value, error, message)) == message : String}

law error_override_preserves_attributes:
  for +error: ErrorTypes.Description<Core.Value>
  for message: String
  {ErrorTypes.attributes(Core.Value, ErrorTypes.with_message(Core.Value, error, message)) == ErrorTypes.attributes(Core.Value, error) : Core.Value}

law error_override_preserves_metadata:
  for +error: ErrorTypes.Description<Core.Value>
  for message: String
  {ErrorTypes.metadata(Core.Value, ErrorTypes.with_message(Core.Value, error, message)) == ErrorTypes.metadata(Core.Value, error) : Core.Value}

law error_assignment_preserves_message:
  for +error: ErrorTypes.Description<Core.Value>
  for value: Core.Value
  {ErrorTypes.message(Core.Value, ErrorTypes.with_assigned_to(Core.Value, error, value)) == ErrorTypes.message(Core.Value, error) : String}

law empty_dependency_order:
  for sensitive: Bool
  {Resolver.find_resolve_order(Core.HashNil{}, sensitive) == Resolver.Ordered{Core.ArrayNil{}} : Resolver.Resolution}

law empty_dependency_cycles:
  for sensitive: Bool
  {Resolver.cycles(Core.HashNil{}, sensitive) == Core.ArrayNil{} : Core.Value}

law dependency_order_preserves_original_key:
  for +original: Core.Value
  {Resolver.order_components(Core.ArrayCons{Core.ArrayCons{Core.TextValue{"name"}, Core.ArrayNil{}}, Core.ArrayNil{}}, [Resolver.Entry{"name", original, Nil{}}]) == Resolver.Ordered{Core.ArrayCons{original, Core.ArrayNil{}}} : Resolver.Resolution}

law empty_hash_read:
  for key: Core.Value
  {Core.hash_get(Core.HashNil{}, key) == Core.NullValue{} : Core.Value}

law member_null:
  for name: String
  for sensitive: Bool
  {Core.member_value(Core.NullValue{}, name, sensitive) == Core.NullValue{} : Core.Value}

law member_error:
  for +message: String
  for name: String
  for sensitive: Bool
  {Core.member_value(Core.Failure{message}, name, sensitive) == Core.Failure{message} : Core.Value}

law modulo_zero_divisor:
  for left: Core.Value
  {Core.modulo(left, Core.Number{0n}) == Core.Failure{"Division by zero"} : Core.Value}

law modulo_right_zero_skips_left:
  for left: Core.Expr
  {Core.evaluate(Core.Modulo{left, Core.Literal{Core.Number{0n}}}) == Core.Failure{"Division by zero"} : Core.Value}

law modulo_right_failure:
  for left: Core.Value
  for +message: String
  {Core.modulo(left, Core.Failure{message}) == Core.Failure{message} : Core.Value}

law empty_comment_prefix:
  for +source: String
  {Comments.strip_comments("/**/" ++ source) == Comments.strip_comments(source) : String}

law empty_formula:
  for context: List<&2, Core.Binding>
  for sensitive: Bool
  {Parser.evaluate("", context, sensitive) == Core.NullValue{} : Core.Value}

law bitwise_left_error:
  for kind: Bits.BitwiseOperation
  for +message: String
  for right: Core.Value
  {Core.bitwise(kind, Core.Failure{message}, right) == Core.Failure{message} : Core.Value}

law bitwise_right_error:
  for kind: Bits.BitwiseOperation
  for left: Nat
  for +message: String
  {Core.bitwise(kind, Core.Number{left}, Core.Failure{message}) == Core.Failure{message} : Core.Value}

law bitwise_false_and_eager:
  for +message: String
  {Core.evaluate(Core.Bitwise{Bits.BitAnd{}, Core.Literal{Core.Logical{False{}}}, Core.Literal{Core.Failure{message}}}) == Core.Failure{message} : Core.Value}

law strict_item_error:
  for +message: String
  {Core.mapped_result(Core.SymbolValue{"strict"}, Core.Failure{message}) == Core.Failure{message} : Core.Value}

law permissive_item_error:
  for message: String
  {Core.mapped_result(Core.SymbolValue{"permissive"}, Core.Failure{message}) == Core.NullValue{} : Core.Value}
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

law empty_enumeration_batch:
  for body: Core.Expr
  for +kind: Core.EnumerationKind
  for binder: String
  for context: List<&2, Core.Binding>
  for sensitive: Bool
  for subjects: List<&2, Core.Value>
  {Core.evaluate_machine(body, Core.EmptyArgumentValues{}, context, sensitive, subjects, Core.EvaluateItems{kind, binder}) == Core.enumeration_empty(kind) : Core.Value}

law empty_reduction_batch:
  for body: Core.Expr
  for memo_name: String
  for item_name: String
  for +initial: Core.Value
  for context: List<&2, Core.Binding>
  for sensitive: Bool
  for subjects: List<&2, Core.Value>
  {Core.evaluate_machine(body, Core.EmptyArgumentValues{}, context, sensitive, subjects, Core.EvaluateReduction{memo_name, item_name, initial}) == initial : Core.Value}

law all_skips_later_predicate:
  for later: Core.Expr
  {Core.evaluate(Core.EnumerationExpression{Core.AllItems{}, Core.Literal{Core.ArrayCons{Core.Logical{False{}}, Core.ArrayCons{Core.Logical{True{}}, Core.ArrayNil{}}}}, "x", Core.If{Core.Variable{"x"}, later, Core.Literal{Core.Logical{False{}}}}}) == Core.Logical{False{}} : Core.Value}

law any_skips_later_predicate:
  for later: Core.Expr
  {Core.evaluate(Core.EnumerationExpression{Core.AnyItems{}, Core.Literal{Core.ArrayCons{Core.Logical{True{}}, Core.ArrayCons{Core.Logical{False{}}, Core.ArrayNil{}}}}, "x", Core.If{Core.Variable{"x"}, Core.Literal{Core.Logical{True{}}}, later}}) == Core.Logical{True{}} : Core.Value}
# Typed decimal transport must preserve signs without broadening ordinary
# formula string coercion or accepting a second sign.
law wire_decimal_negative_zero:
  {Wire.decimal(" \t-0\r\n") == Core.NegativeNumber{Decimal.Exact{Nil{}, 0n}} : Core.Value}

law wire_decimal_positive_zero:
  {Wire.decimal(" \t+0\r\n") == Core.DecimalNumber{Decimal.Exact{Nil{}, 0n}} : Core.Value}

law wire_decimal_single_sign:
  {Wire.decimal(" --0 ") == Core.Failure{"Invalid decimal sign in corpus input"} : Core.Value}

law token_nil_wildcard:
  for category: Core.Value
  for value: Core.Value
  for raw: Core.Value
  {Token.equal(Token.Lexeme{Core.NullValue{}, Core.NullValue{}, Core.NullValue{}}, Token.Lexeme{category, value, raw}) == True{} : Bool}

law token_missing_raw_is_empty:
  for category: Core.Value
  for value: Core.Value
  {Token.is_empty(Token.Lexeme{category, value, Core.NullValue{}}) == True{} : Bool}

law token_raw_does_not_change_equality:
  for +ac: Core.Value
  for +av: Core.Value
  for ar: Core.Value
  for +bc: Core.Value
  for +bv: Core.Value
  for br: Core.Value
  {Token.equal(Token.Lexeme{ac, av, ar}, Token.Lexeme{bc, bv, br}) == Token.equal(Token.Lexeme{ac, av, Core.NullValue{}}, Token.Lexeme{bc, bv, Core.NullValue{}}) : Bool}
law matcher_nil_never_matches_leaf:
  for categories: Core.Value
  for values: Core.Value
  for inverted: Bool
  {Matcher.accepts_predicate(Matcher.Leaf{categories, values, inverted}, None{}) == False{} : Bool}

law matcher_star_minimum:
  for matcher: Matcher.Matcher
  {Matcher.get_minimum(Matcher.star(matcher)) == 0n : Nat}

law matcher_plus_preserves_star_minimum:
  for matcher: Matcher.Matcher
  {Matcher.get_minimum(Matcher.plus(Matcher.star(matcher))) == 0n : Nat}
law matcher_function_category:
  for name: Core.Value
  {Matcher.get_categories(Matcher.for_function(name)) == Core.ArrayCons{Core.SymbolValue{"function"}, Core.ArrayNil{}} : Core.Value}
