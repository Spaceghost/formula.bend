import Base
import ./src/decimal.bend as Decimal
import ./src/core.bend as Core

def main() -> IO(Unit):
  IO.print(Core.show(Core.evaluate(Core.Multiply{Core.Add{Core.Literal{Core.Number{5n}}, Core.Literal{Core.Number{2n}}}, Core.Literal{Core.Number{6n}}})))
