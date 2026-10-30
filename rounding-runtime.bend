import Base
import ./src/core.bend as Core
import ./src/parser.bend as Parser

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Core.show(Parser.evaluate("ROUND(8.2)", Nil{}, False{})))
    IO.print(Core.show(Parser.evaluate("ROUND(8.2759, 2)", Nil{}, False{})))
    IO.print(Core.show(Parser.evaluate("ROUND(-1.25, 1)", Nil{}, False{})))
    IO.print(Core.show(Parser.evaluate("ROUND(125, -1)", Nil{}, False{})))
    IO.print(Core.show(Parser.evaluate("ROUNDUP(-1.21, 1)", Nil{}, False{})))
    IO.print(Core.show(Parser.evaluate("ROUNDDOWN(-1.21, 1)", Nil{}, False{})))
    IO.print(Core.show(Parser.evaluate("ROUNDUP(.1001, 1)", Nil{}, False{})))
    IO.print(Core.show(Parser.evaluate("ROUND(1.256, 1.9)", Nil{}, False{})))
