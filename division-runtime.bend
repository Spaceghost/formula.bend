import Base
import ./src/core.bend as Core
import ./src/parser.bend as Parser

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Core.show(Parser.evaluate("1/3", Nil{}, False{})))
    IO.print(Core.show(Parser.evaluate("2/3", Nil{}, False{})))
    IO.print(Core.show(Parser.evaluate("5/6", Nil{}, False{})))
    IO.print(Core.show(Parser.evaluate("1/8", Nil{}, False{})))
    IO.print(Core.show(Parser.evaluate("10/2", Nil{}, False{})))
    IO.print(Core.show(Parser.evaluate("1000000000000000000000000/3", Nil{}, False{})))
    IO.print(Core.show(Parser.evaluate("0.0000000001/3", Nil{}, False{})))
