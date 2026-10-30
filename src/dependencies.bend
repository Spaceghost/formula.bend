import Base
import ./core.bend as Core

def present_pick(found: Bool, next: Unit -> Bool) -> Bool:
  match found:
    case True{}:
      True{}
    case False{}:
      next(Unit{})

def present(context: List<&2, Core.Binding>, +name: String, +sensitive: Bool) -> Bool:
  match context:
    case Nil{}:
      False{}
    case Core.Bound{key, value} <> rest:
      present_pick(String.eq(Core.normalize(sensitive, key), Core.normalize(sensitive, name)), u => present(rest, name, sensitive))

def contains(names: List<&2, String>, +name: String) -> Bool:
  match names:
    case Nil{}:
      False{}
    case head <> rest:
      present_pick(String.eq(head, name), u => contains(rest, name))

def unique_pick(duplicate: Bool, head: String, next: Unit -> List<&2, String>) -> List<&2, String>:
  match duplicate:
    case True{}:
      next(Unit{})
    case False{}:
      head <> next(Unit{})

def unique(names: List<&2, String>, +seen: List<&2, String>) -> List<&2, String>:
  match names:
    case Nil{}:
      Nil{}
    case +head <> rest:
      unique_pick(contains(seen, head), head, u => unique(rest, head <> seen))

def union(a: List<&2, String>, b: List<&2, String>) -> List<&2, String>:
  unique(List.append(&2, String, a, b), Nil{})

def variable(+name: String, context: List<&2, Core.Binding>, +sensitive: Bool, static: Bool) -> List<&2, String>:
  Bool.pick(List<&2, String>, Bool.or(static, Bool.not(present(context, name, sensitive))), [Core.normalize(sensitive, name)], Nil{})

def branch(chosen: Bool, yes: Unit -> List<&2, String>, no: Unit -> List<&2, String>) -> List<&2, String>:
  match chosen:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def conditional(value: Core.Value, yes: Unit -> List<&2, String>, no: Unit -> List<&2, String>, fallback: Unit -> List<&2, String>) -> List<&2, String>:
  match value:
    case Core.Failure{e}:
      fallback(Unit{})
    case value:
      branch(Core.truthy(value), yes, no)

def probe(value: Core.Value, is_and: Bool) -> Bool:
  match value:
    case Core.Failure{e}:
      False{}
    case value:
      Core.decisive(is_and, value)

def logical(a: List<&2, String>, b: List<&2, String>, left: Core.Expr, right: Core.Expr, is_and: Bool, +context: List<&2, Core.Binding>, +sensitive: Bool) -> List<&2, String>:
  match a b:
    case Nil{} Nil{}:
      Nil{}
    case Nil{} +b:
      Bool.pick(List<&2, String>, probe(Core.evaluate_in(left, context, sensitive), is_and), Nil{}, unique(b, Nil{}))
    case +a Nil{}:
      Bool.pick(List<&2, String>, probe(Core.evaluate_in(right, context, sensitive), is_and), Nil{}, unique(a, Nil{}))
    case a b:
      union(a, b)

def logical_mode(static: Bool, +a: List<&2, String>, +b: List<&2, String>, left: Core.Expr, right: Core.Expr, is_and: Bool, context: List<&2, Core.Binding>, sensitive: Bool) -> List<&2, String>:
  match static:
    case True{}:
      union(a, b)
    case False{}:
      logical(a, b, left, right, is_and, context, sensitive)

def analyze(expr: Core.Expr, +context: List<&2, Core.Binding>, +sensitive: Bool, +static: Bool) -> List<&2, String>:
  match expr:
    case Core.EmptyArguments{}:
      Nil{}
    case Core.Argument{a, validation}:
      analyze(a, context, sensitive, static)
    case Core.Arguments{a, b}:
      x y = analyze(a, context, sensitive, static) analyze(b, context, sensitive, static)
      List.append(&2, String, x, y)
    case Core.FunctionCall{kind, arguments}:
      analyze(arguments, context, sensitive, static)
    case Core.Literal{v}:
      Nil{}
    case Core.Variable{name}:
      variable(name, context, sensitive, static)
    case Core.Add{a, b}:
      x y = analyze(a, context, sensitive, static) analyze(b, context, sensitive, static)
      union(x, y)
    case Core.Subtract{a, b}:
      x y = analyze(a, context, sensitive, static) analyze(b, context, sensitive, static)
      union(x, y)
    case Core.Multiply{a, b}:
      x y = analyze(a, context, sensitive, static) analyze(b, context, sensitive, static)
      union(x, y)
    case Core.Divide{a, b}:
      x y = analyze(a, context, sensitive, static) analyze(b, context, sensitive, static)
      union(x, y)
    case Core.Compare{op, a, b}:
      x y = analyze(a, context, sensitive, static) analyze(b, context, sensitive, static)
      union(x, y)
    case Core.Xor{a, b}:
      x y = analyze(a, context, sensitive, static) analyze(b, context, sensitive, static)
      union(x, y)
    case Core.Round{a, places, mode}:
      x y = analyze(a, context, sensitive, static) analyze(places, context, sensitive, static)
      List.append(&2, String, x, y)
    case Core.Negate{a}:
      analyze(a, context, sensitive, static)
    case Core.Not{a}:
      analyze(a, context, sensitive, static)
    case Core.PrefixNot{a}:
      analyze(a, context, sensitive, static)
    case Core.CoerceNumber{a}:
      analyze(a, context, sensitive, static)
    case Core.And{+a, +b}:
      x y = analyze(a, context, sensitive, static) analyze(b, context, sensitive, static)
      logical_mode(static, x, y, a, b, True{}, context, sensitive)
    case Core.Or{+a, +b}:
      x y = analyze(a, context, sensitive, static) analyze(b, context, sensitive, static)
      logical_mode(static, x, y, a, b, False{}, context, sensitive)
    case Core.If{+c, +a, +b}:
      branch(static, u => union(analyze(c, context, sensitive, True{}), union(analyze(a, context, sensitive, True{}), analyze(b, context, sensitive, True{}))), u => conditional(Core.evaluate_in(c, context, sensitive), u => analyze(a, context, sensitive, False{}), u => analyze(b, context, sensitive, False{}), u => union(analyze(c, context, sensitive, False{}), union(analyze(a, context, sensitive, False{}), analyze(b, context, sensitive, False{})))))
