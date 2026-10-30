import Base
import ./core.bend as Core
import ./dependencies.bend as Dependencies

type ResultKind is Data:
  NumericKind{}
  TextKind{}
  LogicalKind{}
  UnknownKind{}

type Info is Data:
  Metadata{kind: ResultKind, dynamic: Bool, valid: Bool}

def literal(value: Core.Value) -> Info:
  match value:
    case Core.IntegerNumber{n}:
      Metadata{NumericKind{}, False{}, True{}}
    case Core.NegativeInteger{n}:
      Metadata{NumericKind{}, False{}, True{}}
    case Core.Number{n}:
      Metadata{NumericKind{}, False{}, True{}}
    case Core.DecimalNumber{n}:
      Metadata{NumericKind{}, False{}, True{}}
    case Core.NegativeNumber{n}:
      Metadata{NumericKind{}, False{}, True{}}
    case Core.TextValue{s}:
      Metadata{TextKind{}, False{}, True{}}
    case Core.Logical{b}:
      Metadata{LogicalKind{}, False{}, True{}}
    case value:
      Metadata{UnknownKind{}, False{}, True{}}

def numeric_kind(kind: ResultKind, dynamic: Bool, unknown_allowed: Bool) -> Bool:
  match kind:
    case NumericKind{}:
      True{}
    case UnknownKind{}:
      Bool.or(dynamic, unknown_allowed)
    case kind:
      dynamic

def binary(a: Info, b: Info, output: ResultKind, numeric: Bool) -> Info:
  match a b:
    case Metadata{ak, +ad, av} Metadata{bk, +bd, bv}:
      Metadata{output, Bool.or(ad, bd), Bool.and(Bool.and(av, bv), Bool.or(Bool.not(numeric), Bool.and(numeric_kind(ak, ad, True{}), numeric_kind(bk, bd, True{}))))}

def unary(a: Info, output: ResultKind, numeric: Bool) -> Info:
  match a:
    case Metadata{kind, +dynamic, valid}:
      Metadata{output, dynamic, Bool.and(valid, Bool.or(Bool.not(numeric), numeric_kind(kind, dynamic, False{})))}

def conditional(c: Info, a: Info, b: Info) -> Info:
  match c a b:
    case Metadata{ck, cd, cv} Metadata{ak, ad, av} Metadata{bk, bd, bv}:
      Metadata{ak, Bool.or(cd, Bool.or(ad, bd)), Bool.and(cv, Bool.and(av, bv))}

def logical_kind(kind: ResultKind, dynamic: Bool) -> Bool:
  match kind:
    case LogicalKind{}:
      True{}
    case kind:
      dynamic

def logical_binary(a: Info, b: Info) -> Info:
  match a b:
    case Metadata{ak, +ad, av} Metadata{bk, +bd, bv}:
      Metadata{LogicalKind{}, Bool.or(ad, bd), Bool.and(Bool.and(av, bv), Bool.and(logical_kind(ak, ad), logical_kind(bk, bd)))}

def logical_unary(a: Info) -> Info:
  match a:
    case Metadata{kind, +dynamic, valid}:
      Metadata{LogicalKind{}, dynamic, Bool.and(valid, logical_kind(kind, dynamic))}

def function_kind(kind: Core.FunctionKind) -> ResultKind:
  match kind:
    case Core.LeftFunction{}:
      TextKind{}
    case Core.RightFunction{}:
      TextKind{}
    case Core.MidFunction{}:
      TextKind{}
    case Core.SubstituteFunction{}:
      TextKind{}
    case Core.ConcatFunction{}:
      TextKind{}
    case Core.ContainsFunction{}:
      LogicalKind{}
    case Core.SwitchFunction{}:
      LogicalKind{}
    case Core.CountFunction{}:
      UnknownKind{}
    case Core.SumFunction{}:
      NumericKind{}
    case Core.XorFunction{}:
      UnknownKind{}
    case Core.AndFunction{}:
      LogicalKind{}
    case Core.OrFunction{}:
      LogicalKind{}
    case kind:
      NumericKind{}

def function_info(kind: Core.FunctionKind, info: Info) -> Info:
  match info:
    case Metadata{old, dynamic, valid}:
      Metadata{function_kind(kind), dynamic, valid}

def scoped_info(info: Info, dependencies: List<&2, String>) -> Info:
  match info:
    case Metadata{kind, dynamic, valid}:
      Metadata{kind, Bool.not(List.is_empty(&2, String, dependencies)), valid}

# This pass inspects syntax only; it never evaluates a guard or user function.
def analyze_in(+expr: Core.Expr, +sensitive: Bool) -> Info:
  match expr:
    case Core.MidExpression{value, offset, length}:
      binary(analyze_in(value, sensitive), binary(analyze_in(offset, sensitive), analyze_in(length, sensitive), UnknownKind{}, False{}), TextKind{}, False{})
    case Core.ContainsExpression{needle, haystack}:
      binary(analyze_in(needle, sensitive), analyze_in(haystack, sensitive), LogicalKind{}, False{})
    case Core.CountOneExpression{value}:
      unary(analyze_in(value, sensitive), UnknownKind{}, False{})
    case Core.CountManyExpression{arguments, count}:
      unary(analyze_in(arguments, sensitive), UnknownKind{}, False{})
    case Core.EnumerationExpression{kind, collection, binder, body}:
      scoped_info(binary(analyze_in(collection, sensitive), analyze_in(body, sensitive), UnknownKind{}, False{}), Dependencies.analyze(expr, Nil{}, sensitive, True{}))
    case Core.ReductionExpression{collection, memo_binder, item_binder, body, initial}:
      scoped_info(binary(analyze_in(collection, sensitive), binary(analyze_in(body, sensitive), analyze_in(initial, sensitive), UnknownKind{}, False{}), UnknownKind{}, False{}), Dependencies.analyze(expr, Nil{}, sensitive, True{}))
    case Core.CaseExpression{subject, clauses}:
      binary(analyze_in(subject, sensitive), analyze_in(clauses, sensitive), UnknownKind{}, False{})
    case Core.WhenExpression{key, value, rest}:
      binary(analyze_in(key, sensitive), binary(analyze_in(value, sensitive), analyze_in(rest, sensitive), UnknownKind{}, False{}), UnknownKind{}, False{})
    case Core.ElseExpression{value}:
      unary(analyze_in(value, sensitive), UnknownKind{}, False{})
    case Core.NoCaseMatch{}:
      Metadata{UnknownKind{}, False{}, True{}}
    case Core.ArrayLiteral{a}:
      unary(analyze_in(a, sensitive), UnknownKind{}, False{})
    case Core.Access{a, b}:
      x y = analyze_in(a, sensitive) analyze_in(b, sensitive)
      binary(x, y, UnknownKind{}, False{})
    case Core.EmptyArguments{}:
      Metadata{UnknownKind{}, False{}, True{}}
    case Core.Argument{a, validation}:
      unary(analyze_in(a, sensitive), UnknownKind{}, False{})
    case Core.Arguments{a, b}:
      x y = analyze_in(a, sensitive) analyze_in(b, sensitive)
      binary(x, y, UnknownKind{}, False{})
    case Core.FunctionCall{kind, arguments}:
      function_info(kind, analyze_in(arguments, sensitive))
    case Core.Literal{v}:
      literal(v)
    case Core.Variable{name}:
      Metadata{UnknownKind{}, True{}, True{}}
    case Core.Add{a, b}:
      x y = analyze_in(a, sensitive) analyze_in(b, sensitive)
      binary(x, y, NumericKind{}, True{})
    case Core.Subtract{a, b}:
      x y = analyze_in(a, sensitive) analyze_in(b, sensitive)
      binary(x, y, NumericKind{}, True{})
    case Core.Multiply{a, b}:
      x y = analyze_in(a, sensitive) analyze_in(b, sensitive)
      binary(x, y, NumericKind{}, True{})
    case Core.Divide{a, b}:
      x y = analyze_in(a, sensitive) analyze_in(b, sensitive)
      binary(x, y, NumericKind{}, True{})
    case Core.Compare{op, a, b}:
      x y = analyze_in(a, sensitive) analyze_in(b, sensitive)
      binary(x, y, LogicalKind{}, False{})
    case Core.Round{a, places, mode}:
      x y = analyze_in(a, sensitive) analyze_in(places, sensitive)
      binary(x, y, NumericKind{}, False{})
    case Core.Negate{a}:
      unary(analyze_in(a, sensitive), NumericKind{}, True{})
    case Core.Not{a}:
      unary(analyze_in(a, sensitive), LogicalKind{}, False{})
    case Core.And{a, b}:
      x y = analyze_in(a, sensitive) analyze_in(b, sensitive)
      logical_binary(x, y)
    case Core.Or{a, b}:
      x y = analyze_in(a, sensitive) analyze_in(b, sensitive)
      logical_binary(x, y)
    case Core.Xor{a, b}:
      x y = analyze_in(a, sensitive) analyze_in(b, sensitive)
      logical_binary(x, y)
    case Core.PrefixNot{a}:
      logical_unary(analyze_in(a, sensitive))
    case Core.CoerceNumber{a}:
      unary(analyze_in(a, sensitive), NumericKind{}, False{})
    case Core.If{c, a, b}:
      conditional(analyze_in(c, sensitive), analyze_in(a, sensitive), analyze_in(b, sensitive))

def analyze(expr: Core.Expr) -> Info:
  analyze_in(expr, False{})
