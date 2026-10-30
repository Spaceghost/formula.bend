import Base
import ./src/decimal.bend as Decimal
import ./src/core.bend as Core
import ./src/parser.bend as Parser

def show(v: Core.Value) -> String:
  match v:
    case Core.DecimalNumber{n}:
      Decimal.show(n)
    case Core.Number{n}:
      Nat.show(n)
    case Core.Logical{b}:
      Bool.show(b)
    case Core.Failure{e}:
      e

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(show(Parser.evaluate("5 + 3 * 2", Nil{}, False{})))
    IO.print(show(Parser.evaluate("(5 + 3) * 2", Nil{}, False{})))
    IO.print(show(Parser.evaluate("kiwi + 5", [Core.Bound{"KIWI", Core.Number{2n}}], False{})))
    IO.print(show(Parser.evaluate("x2 * 6", [Core.Bound{"x2", Core.Number{7n}}], False{})))
    IO.print(show(Parser.evaluate("missing", Nil{}, False{})))
    IO.print(show(Parser.evaluate("1 +", Nil{}, False{})))
    IO.print(show(Parser.evaluate("SUM(1, 1, 2, 3, 5, 8)", Nil{}, False{})))
    IO.print(show(Parser.evaluate("IF(true, 7, missing)", Nil{}, False{})))
    IO.print(show(Parser.evaluate("NOT(false)", Nil{}, False{})))
    IO.print(show(Parser.evaluate("0.1 + 0.2", Nil{}, False{})))
    IO.print(show(Parser.evaluate("1.25 * .4", Nil{}, False{})))
    IO.print(show(Parser.evaluate("999999999999999999999999.0 + 1.0", Nil{}, False{})))
    IO.print(show(Parser.evaluate("999999999999999999999999 + 1", Nil{}, False{})))
    IO.print(show(Parser.evaluate("999999999 * 999999999", Nil{}, False{})))
