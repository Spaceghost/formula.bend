import Base

# Initial AST evaluator. Nat arithmetic is a prototype, not spreadsheet numeric parity.
type Value is Data:
  Number{value: Nat}
  Logical{value: Bool}
  Failure{message: String}

type Expr is Data:
  Literal{value: Value}
  Variable{name: String}
  Add{left: Expr, right: Expr}
  Multiply{left: Expr, right: Expr}
  If{condition: Expr, yes: Expr, no: Expr}

# Error precedence stays deterministic even when operands run concurrently.
def add(a: Value, b: Value) -> Value:
  match a b:
    case Number{x} Number{y}:
      Number{Nat.add(x, y)}
    case Failure{e} b:
      Failure{e}
    case a Failure{e}:
      Failure{e}
    case a b:
      Failure{"Expected numbers"}

def multiply(a: Value, b: Value) -> Value:
  match a b:
    case Number{x} Number{y}:
      Number{Nat.mul(x, y)}
    case Failure{e} b:
      Failure{e}
    case a Failure{e}:
      Failure{e}
    case a b:
      Failure{"Expected numbers"}

# Branches are closures so the unselected branch is never evaluated.
def choose(c: Value, yes: Unit -> Value, no: Unit -> Value) -> Value:
  match c:
    case Logical{True{}}:
      yes(Unit{})
    case Logical{False{}}:
      no(Unit{})
    case Failure{e}:
      Failure{e}
    case Number{n}:
      Failure{"Expected logical condition"}

type Binding is Data:
  Bound{name: String, value: Value}

def normalize(sensitive: Bool, name: String) -> String:
  match sensitive:
    case True{}:
      name
    case False{}:
      String.to_lower(name)

def found(same: Bool, value: Value, rest: Unit -> Value) -> Value:
  match same:
    case True{}:
      value
    case False{}:
      rest(Unit{})

# First matching binding wins; callers can prepend a transient context.
def lookup(context: List<&2, Binding>, +name: String, +sensitive: Bool) -> Value:
  match context:
    case Nil{}:
      Failure{"Unbound variable: " ++ name}
    case Bound{key, value} <> tail:
      found(String.eq(normalize(sensitive, key), normalize(sensitive, name)), value, u => lookup(tail, name, sensitive))

def evaluate_in(e: Expr, +context: List<&2, Binding>, +sensitive: Bool) -> Value:
  match e:
    case Literal{v}:
      v
    case Variable{name}:
      lookup(context, name, sensitive)
    case Add{a, b}:
      x y = evaluate_in(a, context, sensitive) evaluate_in(b, context, sensitive)
      add(x, y)
    case Multiply{a, b}:
      x y = evaluate_in(a, context, sensitive) evaluate_in(b, context, sensitive)
      multiply(x, y)
    case If{c, a, b}:
      choose(evaluate_in(c, context, sensitive), u => evaluate_in(a, context, sensitive), u => evaluate_in(b, context, sensitive))

def evaluate(e: Expr) -> Value:
  evaluate_in(e, Nil{}, False{})
