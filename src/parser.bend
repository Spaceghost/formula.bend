import Base
import ./core.bend as Core
import ./lexer.bend as Lex

type Stack is Data:
  Ready{operators: List<&2, Lex.Token>, values: List<&2, Core.Expr>}
  Rejected{message: String}

def reduce_times(ops: List<&2, Lex.Token>, values: List<&2, Core.Expr>) -> Stack:
  match ops values:
    case Lex.Times{} <> tail right <> left <> rest:
      reduce_times(tail, Core.Multiply{left, right} <> rest)
    case Lex.Times{} <> tail values:
      Rejected{"Missing operand"}
    case ops values:
      Ready{ops, values}

def reduce_all(ops: List<&2, Lex.Token>, values: List<&2, Core.Expr>) -> Stack:
  match ops values:
    case Lex.Times{} <> tail right <> left <> rest:
      reduce_all(tail, Core.Multiply{left, right} <> rest)
    case Lex.Plus{} <> tail right <> left <> rest:
      reduce_all(tail, Core.Add{left, right} <> rest)
    case Lex.Times{} <> tail values:
      Rejected{"Missing operand"}
    case Lex.Plus{} <> tail values:
      Rejected{"Missing operand"}
    case ops values:
      Ready{ops, values}

def push_operator(stack: Stack, op: Lex.Token) -> Stack:
  match stack:
    case Ready{ops, values}:
      Ready{op <> ops, values}
    case Rejected{e}:
      Rejected{e}

def close_group(stack: Stack) -> Stack:
  match stack:
    case Ready{Lex.LParen{} <> rest, values}:
      Ready{rest, values}
    case Ready{ops, values}:
      Rejected{"Unmatched closing parenthesis"}
    case Rejected{e}:
      Rejected{e}

def identifier(+name: String) -> Core.Expr:
  Bool.pick(Core.Expr, String.eq(String.to_lower(name), "true"), Core.Literal{Core.Logical{True{}}}, Bool.pick(Core.Expr, String.eq(String.to_lower(name), "false"), Core.Literal{Core.Logical{False{}}}, Core.Variable{name}))

def operand(token: Lex.Token, stack: Stack) -> Stack:
  match token stack:
    case Lex.Integer{n} Ready{ops, values}:
      Ready{ops, Core.Literal{Core.Number{n}} <> values}
    case Lex.Identifier{name} Ready{ops, values}:
      Ready{ops, identifier(name) <> values}
    case Lex.LParen{} Ready{ops, values}:
      Ready{Lex.LParen{} <> ops, values}
    case token Rejected{e}:
      Rejected{e}
    case token stack:
      Rejected{"Expected an operand"}

def operator(token: Lex.Token, stack: Stack) -> Stack:
  match token stack:
    case Lex.Plus{} Ready{ops, values}:
      push_operator(reduce_all(ops, values), Lex.Plus{})
    case Lex.Times{} Ready{ops, values}:
      push_operator(reduce_times(ops, values), Lex.Times{})
    case Lex.RParen{} Ready{ops, values}:
      close_group(reduce_all(ops, values))
    case token Rejected{e}:
      Rejected{e}
    case token stack:
      Rejected{"Expected an operator"}

def next_expectation(token: Lex.Token) -> Bool:
  match token:
    case Lex.Integer{n}:
      False{}
    case Lex.Identifier{name}:
      False{}
    case Lex.RParen{}:
      False{}
    case token:
      True{}

def step(expected: Bool, token: Lex.Token, stack: Stack) -> Stack:
  match expected:
    case True{}:
      operand(token, stack)
    case False{}:
      operator(token, stack)

def finish(expected: Bool, stack: Stack) -> Stack:
  match expected:
    case True{}:
      Rejected{"Expected an operand"}
    case False{}:
      stack

def scan(tokens: List<&2, Lex.Token>, stack: Stack, expected: Bool) -> Stack:
  match tokens:
    case Nil{}:
      finish(expected, stack)
    case +head <> tail:
      scan(tail, step(expected, head, stack), next_expectation(head))

type Parsed is Data:
  Accepted{expression: Core.Expr}
  ParseError{message: String}

def completed(stack: Stack) -> Parsed:
  match stack:
    case Ready{Nil{}, expr <> Nil{}}:
      Accepted{expr}
    case Ready{ops, values}:
      ParseError{"Unmatched parenthesis or missing operand"}
    case Rejected{e}:
      ParseError{e}

def drain(stack: Stack) -> Parsed:
  match stack:
    case Ready{ops, values}:
      completed(reduce_all(ops, values))
    case Rejected{e}:
      ParseError{e}

def parse(source: String) -> Parsed:
  drain(scan(Lex.tokenize(source), Ready{Nil{}, Nil{}}, True{}))

def evaluate_parsed(parsed: Parsed, context: List<&2, Core.Binding>, sensitive: Bool) -> Core.Value:
  match parsed:
    case Accepted{expr}:
      Core.evaluate_in(expr, context, sensitive)
    case ParseError{e}:
      Core.Failure{"Parse error: " ++ e}

def evaluate(source: String, context: List<&2, Core.Binding>, sensitive: Bool) -> Core.Value:
  evaluate_parsed(parse(source), context, sensitive)
