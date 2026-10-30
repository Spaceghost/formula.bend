import Base
import ./src/core.bend as Core
import ./src/parser.bend as Parser

def show(v: Core.Value) -> String:
  match v:
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
