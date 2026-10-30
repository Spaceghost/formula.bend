import Base

# Initial AST evaluator. Nat arithmetic is a prototype, not spreadsheet numeric parity.
type Value is Data:
  Number{value: Nat}
  Logical{value: Bool}
  Failure{message: String}

type Expr is Data:
  Literal{value: Value}
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

def evaluate(e: Expr) -> Value:
  match e:
    case Literal{v}:
      v
    case Add{a, b}:
      x y = evaluate(a) evaluate(b)
      add(x, y)
    case Multiply{a, b}:
      x y = evaluate(a) evaluate(b)
      multiply(x, y)
    case If{c, a, b}:
      choose(evaluate(c), u => evaluate(a), u => evaluate(b))
