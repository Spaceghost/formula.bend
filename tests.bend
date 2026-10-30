import Base
import ./src/core.bend as Core
import ./src/reference.bend as Ref

import ./src/parser.bend as Parser
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
