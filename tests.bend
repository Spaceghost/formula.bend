import Base
import ./src/core.bend as Core
import ./src/reference.bend as Ref

import ./src/parser.bend as Parser
import ./src/decimal.bend as Decimal
# Concrete regression fixtures complement the universal laws.
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

def unsupported_character() -> {Parser.parse("1 / 2") == Parser.ParseError{"Expected an operator"} : Parser.Parsed}:
  {==}

def unmatched_group() -> {Parser.parse("(1 + 2") == Parser.ParseError{"Unmatched parenthesis or missing operand"} : Parser.Parsed}:
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

def empty_sum() -> {Parser.parse("SUM()") == Parser.ParseError{"SUM expects at least one argument"} : Parser.Parsed}:
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

def trailing_decimal_point() -> {Parser.parse("1.") == Parser.ParseError{"Expected an operand"} : Parser.Parsed}:
  {==}

def large_integer_literal() -> {Core.show(Parser.evaluate("999999999999999999999999 + 1", Nil{}, False{})) == "1000000000000000000000000" : String}:
  {==}

def integer_product_over_word() -> {Core.show(Parser.evaluate("999999999 * 999999999", Nil{}, False{})) == "999999998000000001" : String}:
  {==}
