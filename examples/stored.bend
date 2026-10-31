import Base
import ../src/core.bend as Core
import ../src/stored.bend as Stored

def main() -> IO(Unit):
  IO.print(Core.snapshot(Stored.evaluate_in(Core.Add{Core.Variable{"f"}, Core.Literal{Core.Number{1n}}}, [Core.ScopedBound{"f", Core.StoredExpression{Core.Multiply{Core.Variable{"a"}, Core.Literal{Core.Number{3n}}}, False{}}}, Core.ScopedBound{"a", Core.Number{2n}}], False{})))
