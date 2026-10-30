import Base
import ./src/decimal.bend as Decimal
import ./src/core.bend as Core

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
  IO.print(show(Core.evaluate(Core.Multiply{Core.Add{Core.Literal{Core.Number{5n}}, Core.Literal{Core.Number{2n}}}, Core.Literal{Core.Number{6n}}})))
