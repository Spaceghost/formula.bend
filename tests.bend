import Base
import ./src/core.bend as Core
import ./src/reference.bend as Ref

import ./src/parser.bend as Parser
import ./src/decimal.bend as Decimal
import ./src/division.bend as Division
import ./src/address.bend as Address
# Concrete regression fixtures complement the universal laws.
def member_access_node() -> {Parser.parse("users[0].age") == Parser.Accepted{Core.Access{Core.Access{Core.Variable{"users"}, Core.Literal{Core.Number{0n}}}, Core.Literal{Core.MemberIndex{"age"}}}} : Parser.Parsed}:
  {==}

def arithmetic() -> {Core.evaluate(Core.Multiply{Core.Add{Core.Literal{Core.Number{5n}}, Core.Literal{Core.Number{2n}}}, Core.Literal{Core.Number{6n}}}) == Core.Number{42n} : Core.Value}:
  {==}

def unused_failure() -> {Core.evaluate(Core.If{Core.Literal{Core.Logical{True{}}}, Core.Literal{Core.Number{7n}}, Core.Literal{Core.Failure{"unbound"}}}) == Core.Number{7n} : Core.Value}:
  {==}

def left_error() -> {Core.evaluate(Core.Add{Core.Literal{Core.Failure{"left"}}, Core.Literal{Core.Failure{"right"}}}) == Core.Failure{"left"} : Core.Value}:
  {==}

def both_relative() -> {Ref.copy_forward(Ref.Cell{Ref.Relative{0n}, Ref.Relative{0n}}, 2n, 3n) == Ref.Cell{Ref.Relative{2n}, Ref.Relative{3n}} : Ref.Reference}:
  {==}

def column_absolute() -> {Ref.copy_forward(Ref.Cell{Ref.Relative{0n}, Ref.Absolute{0n}}, 2n, 3n) == Ref.Cell{Ref.Relative{2n}, Ref.Absolute{0n}} : Ref.Reference}:
  {==}

def both_absolute() -> {Ref.copy_forward(Ref.Cell{Ref.Absolute{0n}, Ref.Absolute{0n}}, 2n, 3n) == Ref.Cell{Ref.Absolute{0n}, Ref.Absolute{0n}} : Ref.Reference}:
  {==}

def parsed_precedence() -> {Parser.evaluate("5 + 3 * 2", Nil{}, False{}) == Core.Number{11n} : Core.Value}:
  {==}

def parsed_parentheses() -> {Parser.evaluate("(5 + 3) * 2", Nil{}, False{}) == Core.Number{16n} : Core.Value}:
  {==}

def bound_formula() -> {Parser.evaluate("kiwi + 5", [Core.Bound{"KIWI", Core.Number{2n}}], False{}) == Core.Number{7n} : Core.Value}:
  {==}

def sensitive_formula() -> {Parser.evaluate("Kiwi + 5", [Core.Bound{"Kiwi", Core.Number{3n}}, Core.Bound{"kiwi", Core.Number{2n}}], True{}) == Core.Number{8n} : Core.Value}:
  {==}

def first_binding_wins() -> {Parser.evaluate("kiwi", [Core.Bound{"kiwi", Core.Number{9n}}, Core.Bound{"kiwi", Core.Number{2n}}], False{}) == Core.Number{9n} : Core.Value}:
  {==}

def missing_binding() -> {Parser.evaluate("missing", Nil{}, False{}) == Core.Failure{"Unbound variable: missing"} : Core.Value}:
  {==}

def trailing_operator() -> {Parser.parse("1 +") == Parser.ParseError{"Expected an operand"} : Parser.Parsed}:
  {==}

def empty_group() -> {Parser.parse("()") == Parser.ParseError{"Expected an operand"} : Parser.Parsed}:
  {==}

def unsupported_character() -> {Parser.parse("1 @ 2") == Parser.ParseError{"Expected an operator"} : Parser.Parsed}:
  {==}

def unmatched_group() -> {Parser.parse("(1 + 2") == Parser.ParseError{"Tokenizer: unbalanced parentheses"} : Parser.Parsed}:
  {==}

def adjacent_operands() -> {Parser.parse("1 2") == Parser.ParseError{"Expected an operator"} : Parser.Parsed}:
  {==}

def identifier_digits() -> {Parser.evaluate("x2 * 6", [Core.Bound{"x2", Core.Number{7n}}], False{}) == Core.Number{42n} : Core.Value}:
  {==}

def left_associative_parse() -> {Parser.parse("1 + 2 + 3") == Parser.Accepted{Core.Add{Core.Add{Core.Literal{Core.Number{1n}}, Core.Literal{Core.Number{2n}}}, Core.Literal{Core.Number{3n}}}} : Parser.Parsed}:
  {==}

def logical_literal() -> {Parser.evaluate("TrUe", Nil{}, False{}) == Core.Logical{True{}} : Core.Value}:
  {==}

def sum_call() -> {Parser.evaluate("SUM(1, 1, 2, 3, 5, 8)", Nil{}, False{}) == Core.Number{20n} : Core.Value}:
  {==}

def nested_calls() -> {Parser.evaluate("2 * SUM(1, SUM(2, 3), (4 + 5))", Nil{}, False{}) == Core.Number{30n} : Core.Value}:
  {==}

def lazy_function() -> {Parser.evaluate("IF(true, 7, missing)", Nil{}, False{}) == Core.Number{7n} : Core.Value}:
  {==}

def alternate_function() -> {Parser.evaluate("if(false, missing, 9)", Nil{}, False{}) == Core.Number{9n} : Core.Value}:
  {==}

def not_function() -> {Parser.evaluate("NOT(false)", Nil{}, False{}) == Core.Logical{True{}} : Core.Value}:
  {==}

def empty_sum() -> {Parser.snapshot("SUM()", Nil{}, False{}) == "error:Dentaku::ArgumentError" : String}:
  {==}

def trailing_comma() -> {Parser.parse("SUM(1,)") == Parser.ParseError{"Expected an operand"} : Parser.Parsed}:
  {==}

def comma_in_group() -> {Parser.parse("SUM((1,2))") == Parser.ParseError{"Comma outside a function argument list"} : Parser.Parsed}:
  {==}

def too_few_if() -> {Parser.parse("IF(true,1)") == Parser.ParseError{"IF expects three arguments"} : Parser.Parsed}:
  {==}

def unknown_function() -> {Parser.parse("UNKNOWN(1)") == Parser.ParseError{"Unknown function: UNKNOWN"} : Parser.Parsed}:
  {==}

def decimal_addition() -> {Decimal.show(Decimal.add(Decimal.Exact{[1], 1n}, Decimal.Exact{[2], 1n})) == "0.3" : String}:
  {==}

def decimal_carry() -> {Decimal.show(Decimal.add(Decimal.Exact{[9,9,9,9], 2n}, Decimal.Exact{[1], 2n})) == "100.00" : String}:
  {==}

def decimal_align() -> {Decimal.show(Decimal.add(Decimal.Exact{[1], 0n}, Decimal.Exact{[1], 3n})) == "1.001" : String}:
  {==}

def decimal_product() -> {Decimal.show(Decimal.multiply(Decimal.Exact{[5,2,1], 2n}, Decimal.Exact{[4], 1n})) == "0.500" : String}:
  {==}

def decimal_large() -> {Decimal.show(Decimal.add(Decimal.Exact{[9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9], 0n}, Decimal.Exact{[1], 0n})) == "1000000000000000000000000" : String}:
  {==}

def decimal_formula() -> {Core.show(Parser.evaluate("0.1 + 0.2", Nil{}, False{})) == "0.3" : String}:
  {==}

def mixed_decimal_formula() -> {Core.show(Parser.evaluate("1 + .001", Nil{}, False{})) == "1.001" : String}:
  {==}

def decimal_function() -> {Core.show(Parser.evaluate("SUM(0.1, .2, 0.3)", Nil{}, False{})) == "0.6" : String}:
  {==}

def decimal_multiplication_formula() -> {Core.show(Parser.evaluate("1.25 * .4", Nil{}, False{})) == "0.500" : String}:
  {==}

def large_decimal_formula() -> {Core.show(Parser.evaluate("999999999999999999999999.0 + 1.0", Nil{}, False{})) == "1000000000000000000000000.0" : String}:
  {==}

def repeated_decimal_point() -> {Parser.parse("1.2.3") == Parser.ParseError{"Expected an operator"} : Parser.Parsed}:
  {==}

def trailing_decimal_point() -> {Parser.parse("1.") == Parser.ParseError{"Tokenizer: invalid numeric literal"} : Parser.Parsed}:
  {==}

def large_integer_literal() -> {Core.show(Parser.evaluate("999999999999999999999999 + 1", Nil{}, False{})) == "1000000000000000000000000" : String}:
  {==}

def integer_product_over_word() -> {Core.show(Parser.evaluate("999999999 * 999999999", Nil{}, False{})) == "999999998000000001" : String}:
  {==}

def signed_integer() -> {Core.show(Parser.evaluate("1 - 2", Nil{}, False{})) == "-1" : String}:
  {==}

def signed_decimal() -> {Core.show(Parser.evaluate("-.1 + .2", Nil{}, False{})) == "0.1" : String}:
  {==}

def signed_product() -> {Core.show(Parser.evaluate("-2 * -3", Nil{}, False{})) == "6" : String}:
  {==}

def signed_group() -> {Core.show(Parser.evaluate("-(2 + 3) * 4", Nil{}, False{})) == "-20" : String}:
  {==}

def subtract_associative() -> {Core.show(Parser.evaluate("10 - 3 - 2", Nil{}, False{})) == "5" : String}:
  {==}

def decimal_borrow() -> {Core.show(Parser.evaluate("1000.00 - .01", Nil{}, False{})) == "999.99" : String}:
  {==}

def subtract_negative() -> {Core.show(Parser.evaluate("1 - -2", Nil{}, False{})) == "3" : String}:
  {==}

def zero_sign() -> {Core.show(Parser.evaluate("-.0", Nil{}, False{})) == "-0.0" : String}:
  {==}

def repeated_negation() -> {Core.show(Parser.evaluate("--2", Nil{}, False{})) == "2" : String}:
  {==}

def signed_sum() -> {Core.show(Parser.evaluate("SUM(-2.5, 1, .5)", Nil{}, False{})) == "-1.0" : String}:
  {==}

def large_subtraction() -> {Core.show(Parser.evaluate("1000000000000000000000000 - 1", Nil{}, False{})) == "999999999999999999999999" : String}:
  {==}

def round_default() -> {Core.show(Parser.evaluate("ROUND(8.2)", Nil{}, False{})) == "8" : String}:
  {==}

def round_places() -> {Core.show(Parser.evaluate("ROUND(8.2759, 2)", Nil{}, False{})) == "8.28" : String}:
  {==}

def round_negative_tie() -> {Core.show(Parser.evaluate("ROUND(-1.25, 1)", Nil{}, False{})) == "-1.3" : String}:
  {==}

def round_tens() -> {Core.show(Parser.evaluate("ROUND(125, -1)", Nil{}, False{})) == "130" : String}:
  {==}

def ruby_roundup_negative() -> {Core.show(Parser.evaluate("ROUNDUP(-1.21, 1)", Nil{}, False{})) == "-1.2" : String}:
  {==}

def ruby_rounddown_negative() -> {Core.show(Parser.evaluate("ROUNDDOWN(-1.21, 1)", Nil{}, False{})) == "-1.3" : String}:
  {==}

def roundup_sticky() -> {Core.show(Parser.evaluate("ROUNDUP(.1001, 1)", Nil{}, False{})) == "0.2" : String}:
  {==}

def rounddown_sticky() -> {Core.show(Parser.evaluate("ROUNDDOWN(.1001, 1)", Nil{}, False{})) == "0.1" : String}:
  {==}

def round_precision_truncates() -> {Core.show(Parser.evaluate("ROUND(1.256, 1.9)", Nil{}, False{})) == "1.3" : String}:
  {==}

def round_arity() -> {Parser.parse("ROUND(1,2,3)") == Parser.ParseError{"Rounding expects one or two arguments"} : Parser.Parsed}:
  {==}

def round_zero_precision_padding() -> {Core.show(Parser.evaluate("ROUND(1.5, 000000000000000)", Nil{}, False{})) == "2" : String}:
  {==}

def exact_division() -> {Division.show(Division.divide(Decimal.Exact{[1], 0n}, Decimal.Exact{[8], 0n}, 3n)) == "0.125" : String}:
  {==}

def repeating_division() -> {Division.show(Division.divide(Decimal.Exact{[1], 0n}, Decimal.Exact{[3], 0n}, 4n)) == "0.3333" : String}:
  {==}

def division_remainder() -> {Division.divide(Decimal.Exact{[5], 0n}, Decimal.Exact{[6], 0n}, 4n) == Division.Quotient{Decimal.Exact{[3,3,3,8], 4n}, [2], [6]} : Division.DivisionResult}:
  {==}

def scaled_division() -> {Division.show(Division.divide(Decimal.Exact{[5,2,1], 2n}, Decimal.Exact{[5], 1n}, 1n)) == "2.5" : String}:
  {==}

def division_zero() -> {Division.divide(Decimal.Exact{[1], 0n}, Decimal.Exact{[0,0], 1n}, 4n) == Division.DivisionByZero{} : Division.DivisionResult}:
  {==}

def default_repeating_division() -> {Core.show(Parser.evaluate("1 / 3", Nil{}, False{})) == "0.333333333333333333333333333333333333" : String}:
  {==}

def rounded_repeating_division() -> {Core.show(Parser.evaluate("2 / 3", Nil{}, False{})) == "0.666666666666666666666666666666666667" : String}:
  {==}

def division_precedence() -> {Core.show(Parser.evaluate("12 / 2 * 3", Nil{}, False{})) == "18" : String}:
  {==}

def signed_division() -> {Core.show(Parser.evaluate("-1 / 8", Nil{}, False{})) == "-0.125" : String}:
  {==}

def division_zero_formula() -> {Parser.evaluate("1 / 0", Nil{}, False{}) == Core.Failure{"Division by zero"} : Core.Value}:
  {==}

def lazy_zero_division() -> {Core.show(Parser.evaluate("IF(true, 7, 1 / 0)", Nil{}, False{})) == "7" : String}:
  {==}

def a1_relative() -> {Address.parse_a1("A1", 1n, 1n) == Address.GoodAddress{Address.AddressCell{Address.Displaced{True{}, 1n}, Address.Displaced{True{}, 1n}, Address.A1Style{}}} : Address.ParsedAddress}:
  {==}

def a1_absolute() -> {Address.parse_a1("$A$1", 10n, 20n) == Address.GoodAddress{Address.AddressCell{Address.Fixed{0n}, Address.Fixed{0n}, Address.A1Style{}}} : Address.ParsedAddress}:
  {==}

def a1_column_anchor() -> {Address.resolve_parsed(Address.parse_a1("$A1", 1n, 1n), 4n, 3n, 100n, 100n) == Address.At{3n, 0n} : Address.Resolved}:
  {==}

def a1_row_anchor() -> {Address.resolve_parsed(Address.parse_a1("A$1", 1n, 1n), 4n, 3n, 100n, 100n) == Address.At{0n, 2n} : Address.Resolved}:
  {==}

def a1_multiple_letters() -> {Address.resolve_parsed(Address.parse_a1("aa10", 0n, 0n), 0n, 0n, 100n, 100n) == Address.At{9n, 26n} : Address.Resolved}:
  {==}

def a1_zero_row() -> {Address.parse_a1("A0", 0n, 0n) == Address.BadAddress{"Invalid A1 address"} : Address.ParsedAddress}:
  {==}

def a1_missing_column() -> {Address.parse_a1("1", 0n, 0n) == Address.BadAddress{"Invalid A1 address"} : Address.ParsedAddress}:
  {==}

def a1_double_anchor() -> {Address.parse_a1("$$A1", 0n, 0n) == Address.BadAddress{"Invalid A1 address"} : Address.ParsedAddress}:
  {==}

def reference_before_origin() -> {Address.resolve_parsed(Address.parse_a1("A1", 1n, 1n), 0n, 0n, 100n, 100n) == Address.ReferenceError{} : Address.Resolved}:
  {==}

def reference_beyond_sheet() -> {Address.resolve_parsed(Address.parse_a1("B2", 0n, 0n), 9n, 9n, 10n, 10n) == Address.ReferenceError{} : Address.Resolved}:
  {==}

def rc_absolute() -> {Address.parse_r1c1("R1C2") == Address.GoodAddress{Address.AddressCell{Address.Fixed{0n}, Address.Fixed{1n}, Address.R1C1Style{}}} : Address.ParsedAddress}:
  {==}

def rc_relative() -> {Address.resolve_parsed(Address.parse_r1c1("R[-1]C[2]"), 5n, 5n, 100n, 100n) == Address.At{4n, 7n} : Address.Resolved}:
  {==}

def rc_current_cell() -> {Address.resolve_parsed(Address.parse_r1c1("RC"), 5n, 5n, 100n, 100n) == Address.At{5n, 5n} : Address.Resolved}:
  {==}

def rc_mixed() -> {Address.resolve_parsed(Address.parse_r1c1("R1C[-2]"), 5n, 5n, 100n, 100n) == Address.At{0n, 3n} : Address.Resolved}:
  {==}

def rc_explicit_plus() -> {Address.resolve_parsed(Address.parse_r1c1("r[+2]c1"), 5n, 5n, 100n, 100n) == Address.At{7n, 0n} : Address.Resolved}:
  {==}

def rc_zero_absolute() -> {Address.parse_r1c1("R0C1") == Address.BadAddress{"Invalid R1C1 axis"} : Address.ParsedAddress}:
  {==}

def rc_missing_bracket() -> {Address.parse_r1c1("R[1C1") == Address.BadAddress{"Invalid R1C1 axis"} : Address.ParsedAddress}:
  {==}

def rc_missing_offset() -> {Address.parse_r1c1("R[]C1") == Address.BadAddress{"Invalid R1C1 axis"} : Address.ParsedAddress}:
  {==}

def rc_repeated_column() -> {Address.parse_r1c1("R1C1C1") == Address.BadAddress{"Invalid R1C1 address"} : Address.ParsedAddress}:
  {==}

def a1_copy_render() -> {Address.render_parsed_a1(Address.parse_a1("$A1", 1n, 1n), 4n, 3n, 100n, 100n) == "$A4" : String}:
  {==}

def a1_to_rc() -> {Address.render_parsed_r1c1(Address.parse_a1("$A1", 1n, 1n)) == "R[-1]C1" : String}:
  {==}

def rc_to_a1() -> {Address.render_parsed_a1(Address.parse_r1c1("R[-1]C[2]"), 5n, 5n, 100n, 100n) == "H5" : String}:
  {==}

def column_carry_render() -> {Address.render_parsed_a1(Address.parse_a1("Z1", 0n, 0n), 0n, 1n, 100n, 100n) == "AA1" : String}:
  {==}

def ruby_numeric_guard() -> {Core.show(Parser.evaluate("IF(0, 1, 2)", Nil{}, False{})) == "1" : String}:
  {==}

def ruby_null_guard() -> {Core.show(Parser.evaluate("IF(null, 1, 2)", Nil{}, False{})) == "2" : String}:
  {==}

def ruby_empty_string_guard() -> {Core.show(Parser.evaluate("IF('', 1, 2)", Nil{}, False{})) == "1" : String}:
  {==}

def ruby_numeric_not() -> {Parser.evaluate("NOT(0)", Nil{}, False{}) == Core.Logical{False{}} : Core.Value}:
  {==}

def ruby_null_not() -> {Parser.evaluate("NOT(NULL)", Nil{}, False{}) == Core.Logical{True{}} : Core.Value}:
  {==}

def ruby_string_not() -> {Parser.evaluate("NOT('')", Nil{}, False{}) == Core.Logical{False{}} : Core.Value}:
  {==}

def literal_quoted_text() -> {Parser.evaluate("'a 1 + (b)'", Nil{}, False{}) == Core.TextValue{"a 1 + (b)"} : Core.Value}:
  {==}

def literal_double_quoted_text() -> {Parser.evaluate("\"a 'b'\"", Nil{}, False{}) == Core.TextValue{"a 'b'"} : Core.Value}:
  {==}

def missing_closing_quote() -> {Parser.parse("'missing") == Parser.ParseError{"Expected an operand"} : Parser.Parsed}:
  {==}

def separated_comparator_symbols() -> {Parser.parse("1 < = 2") == Parser.ParseError{"Expected an operand"} : Parser.Parsed}:
  {==}

def trailing_comparison_operator() -> {Parser.parse("1 >") == Parser.ParseError{"Expected an operand"} : Parser.Parsed}:
  {==}

def comparison_grouping() -> {Parser.evaluate("(1 < 2) = true", Nil{}, False{}) == Core.Logical{True{}} : Core.Value}:
  {==}

def resolved_guard_dependencies() -> {Parser.dependencies("IF(x > 5, y, z)", [Core.Bound{"x", Core.Number{7n}}], False{}) == Parser.FoundNames{["y"]} : Parser.NamesResult}:
  {==}

def syntactic_identifiers_do_not_prune() -> {Parser.identifiers("false AND missing", False{}) == Parser.FoundNames{["missing"]} : Parser.NamesResult}:
  {==}

def logical_dependency_pruning() -> {Parser.dependencies("missing OR true", Nil{}, False{}) == Parser.FoundNames{Nil{}} : Parser.NamesResult}:
  {==}

def logical_left_associative() -> {Parser.evaluate("true OR false AND false", Nil{}, False{}) == Core.Logical{False{}} : Core.Value}:
  {==}

def prefix_not_comparison_binding() -> {Parser.evaluate("NOT 1 < 2", Nil{}, False{}) == Core.Logical{False{}} : Core.Value}:
  {==}

def operator_not_rejects_numeric_literal() -> {Parser.parse("NOT 0") == Parser.ParseError{"Invalid static operand type"} : Parser.Parsed}:
  {==}

def function_dependency_duplicates_retained() -> {Parser.dependencies("SUM(a, a)", Nil{}, False{}) == Parser.FoundNames{["a", "a"]} : Parser.NamesResult}:
  {==}

def function_identifiers_deduplicated() -> {Parser.identifiers("SUM(a, a)", False{}) == Parser.FoundNames{["a"]} : Parser.NamesResult}:
  {==}

def logical_function_eager_value_error() -> {Parser.snapshot("AND(false, 1 / 0 = 0)", Nil{}, False{}) == "error:Dentaku::ZeroDivisionError" : String}:
  {==}

def logical_function_type_validation_order() -> {Parser.evaluate("AND(false, 7)", Nil{}, False{}) == Core.Logical{False{}} : Core.Value}:
  {==}

def logical_xor_parity() -> {Parser.evaluate("XOR(true, true, true)", Nil{}, False{}) == Core.Logical{True{}} : Core.Value}:
  {==}

def sum_empty_branch_is_lazy() -> {Parser.evaluate("IF(true, 7, SUM())", Nil{}, False{}) == Core.Number{7n} : Core.Value}:
  {==}

def count_bound_string() -> {Parser.evaluate("COUNT(x)", [Core.Bound{"x", Core.TextValue{"dentaku"}}], False{}) == Core.Number{7n} : Core.Value}:
  {==}

def count_bound_array() -> {Parser.evaluate("COUNT(x)", [Core.Bound{"x", Core.ArrayCons{Core.Number{4n}, Core.ArrayCons{Core.Number{5n}, Core.ArrayNil{}}}}], False{}) == Core.Number{2n} : Core.Value}:
  {==}

def array_bound_access() -> {Parser.evaluate("a[1]", [Core.Bound{"a", Core.ArrayCons{Core.Number{1n}, Core.ArrayCons{Core.Number{2n}, Core.ArrayNil{}}}}], False{}) == Core.Number{2n} : Core.Value}:
  {==}

def count_multiple_skips_values() -> {Parser.evaluate("COUNT(1 / 0, 2)", Nil{}, False{}) == Core.Number{2n} : Core.Value}:
  {==}

def null_access_skips_division() -> {Parser.evaluate("null[1 / 0]", Nil{}, False{}) == Core.NullValue{} : Core.Value}:
  {==}

def array_nested_index() -> {Parser.evaluate("{{1, 2}, {3, 4}}[1][0]", Nil{}, False{}) == Core.Number{3n} : Core.Value}:
  {==}

def array_nested_sum() -> {Parser.evaluate("SUM({1, {2, 3}}, 4)", Nil{}, False{}) == Core.Number{10n} : Core.Value}:
  {==}

def scientific_exact_large_addition() -> {Parser.snapshot("1e20 + 1", Nil{}, False{}) == "number:100000000000000000001" : String}:
  {==}

def hex_exact_large_literal() -> {Parser.snapshot("0xFFFFFFFFFFFFFFFFFFFFFFFF", Nil{}, False{}) == "number:79228162514264337593543950335" : String}:
  {==}

def numeric_string_rejects_internal_space() -> {Parser.snapshot("SUM('- 2')", Nil{}, False{}) == "error:Dentaku::ArgumentError" : String}:
  {==}

def scientific_zero_snapshot() -> {Parser.snapshot("0e-3", Nil{}, False{}) == "number:0" : String}:
  {==}

def big_integer_class_retained() -> {Parser.class_snapshot("100000000000000000000 + 1", Nil{}, False{}) == "class:Integer" : String}:
  {==}

def negative_integer_class_retained() -> {Parser.class_snapshot("-2 * 3", Nil{}, False{}) == "class:Integer" : String}:
  {==}

def decimal_integral_division_class() -> {Parser.class_snapshot("4 / 2", Nil{}, False{}) == "class:BigDecimal" : String}:
  {==}

def integer_positive_precision_class() -> {Parser.class_snapshot("ROUND(1, 2)", Nil{}, False{}) == "class:Integer" : String}:
  {==}

def mid_zero_offset_from_end() -> {Parser.snapshot("MID('abcdefg', 0, 2)", Nil{}, False{}) == "string:g" : String}:
  {==}

def mid_validates_before_length_value() -> {Parser.snapshot("MID('abc', -1, 1 / 0)", Nil{}, False{}) == "error:Dentaku::ArgumentError" : String}:
  {==}

def contains_evaluates_haystack_first() -> {Parser.snapshot("CONTAINS(1 / 0, ABS('x'))", Nil{}, False{}) == "error:Dentaku::ArgumentError" : String}:
  {==}

def concat_bigdecimal_scientific_form() -> {Parser.snapshot("CONCAT(1000.0)", Nil{}, False{}) == "string:0.1e4" : String}:
  {==}

def concat_integer_fixed_form() -> {Parser.snapshot("CONCAT(1000)", Nil{}, False{}) == "string:1000" : String}:
  {==}

def substitute_only_first_match() -> {Parser.snapshot("SUBSTITUTE('ababab', 'ab', 'x')", Nil{}, False{}) == "string:xabab" : String}:
  {==}

def switch_uses_first_match() -> {Parser.snapshot("SWITCH(1, 1, 'one', 1, 'two')", Nil{}, False{}) == "string:one" : String}:
  {==}

def switch_values_are_eager() -> {Parser.snapshot("SWITCH(1, 1, 7, 2, 1 / 0)", Nil{}, False{}) == "error:Dentaku::ZeroDivisionError" : String}:
  {==}

def negative_zero_string() -> {Parser.snapshot("CONCAT(-0.0)", Nil{}, False{}) == "string:-0.0" : String}:
  {==}

def negative_zero_ordering() -> {Parser.snapshot("-0.0 < 0", Nil{}, False{}) == "boolean:false" : String}:
  {==}

def negative_zero_index() -> {Parser.snapshot("{1, 2}[-0.0]", Nil{}, False{}) == "number:1" : String}:
  {==}

def sum_negative_zero_identity() -> {Parser.snapshot("SUM(-0.0, -0.0)", Nil{}, False{}) == "number:0" : String}:
  {==}

def case_selects_first_match() -> {Parser.snapshot("CASE 1 WHEN 1 THEN 7 WHEN 1 THEN 8 END", Nil{}, False{}) == "number:7" : String}:
  {==}

def case_skips_later_key() -> {Parser.snapshot("CASE 1 WHEN 1 THEN 7 WHEN 1 / 0 THEN 8 END", Nil{}, False{}) == "number:7" : String}:
  {==}

def case_keys_do_not_coerce_strings() -> {Parser.snapshot("CASE '1' WHEN 1 THEN 7 ELSE 8 END", Nil{}, False{}) == "number:8" : String}:
  {==}

def case_failing_probe_retains_all_dependencies() -> {Parser.names_snapshot(Parser.dependencies("CASE 1 WHEN 2 THEN a WHEN missing THEN b ELSE c END", Nil{}, False{})) == "names:a,missing,b,c" : String}:
  {==}

def case_nested_scopes() -> {Parser.snapshot("CASE CASE 1 WHEN 1 THEN 2 END WHEN 2 THEN 3 END", Nil{}, False{}) == "number:3" : String}:
  {==}

def case_unknown_static_kind() -> {Parser.type_snapshot("CASE 1 WHEN 1 THEN 2 END") == "type:nil" : String}:
  {==}

def map_values() -> {Parser.snapshot("MAP({1, 2}, v, v + 1)", Nil{}, False{}) == "array:[8:number:28:number:3]" : String}:
  {==}

def filter_values() -> {Parser.snapshot("FILTER({0, 1, 2}, v, v > 1)", Nil{}, False{}) == "array:[8:number:2]" : String}:
  {==}

def any_predicate_is_lazy() -> {Parser.snapshot("ANY({1, 0}, v, 1 / v > 0)", Nil{}, False{}) == "boolean:true" : String}:
  {==}

def reduce_nil_initial_string() -> {Parser.snapshot("REDUCE({'a', 'b'}, memo, v, CONCAT(memo, v))", Nil{}, False{}) == "string:ab" : String}:
  {==}

def map_binder_message() -> {Parser.message_snapshot("MAP({1}, 'v', v)", Nil{}, False{}) == "message:MAP() requires second argument to be an identifier" : String}:
  {==}

def local_enum_dependencies_do_not_validate_as_logical() -> {Parser.snapshot("MAP({1}, X, x) AND true", Nil{}, False{}) == "error:Dentaku::ParseError" : String}:
  {==}

def enum_sensitive_external_name_validates_as_dynamic() -> {Parser.snapshot("MAP({1}, X, x) AND true", [Core.Bound{"x", Core.Logical{True{}}}], True{}) == "boolean:true" : String}:
  {==}

def enum_static_identifiers_exclude_binder() -> {Parser.names_snapshot(Parser.identifiers("MAP(vals, v, v + tax)", False{})) == "names:vals,tax" : String}:
  {==}
