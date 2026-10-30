import Base
import ./src/core.bend as Core
import ./src/parser.bend as Parser

def values(count: Nat) -> Core.Value:
  match count:
    case 0n:
      Core.ArrayNil{}
    case 1n+ +p:
      Core.ArrayCons{Core.Number{1n+p}, values(p)}

def check(source: String) -> String:
  Parser.snapshot(source, [Core.Bound{"vals", values(1025n)}], False{})

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("scale_map_sum\t" ++ check("SUM(MAP(vals,v,v+1))"))
    IO.print("scale_filter_sum\t" ++ check("SUM(FILTER(vals,v,v>1020))"))
    IO.print("scale_all\t" ++ check("ALL(vals,v,v>0)"))
    IO.print("scale_any_last\t" ++ check("ANY(vals,v,v=1)"))
    IO.print("scale_reduce\t" ++ check("REDUCE(vals,memo,v,memo+v,0)"))
    IO.print("scale_map_count\t" ++ check("COUNT(MAP(vals,v,v+1))"))
    IO.print("scale_case_body\t" ++ check("SUM(MAP(vals,v,CASE v WHEN 1025 THEN -0.0 ELSE v END))"))
