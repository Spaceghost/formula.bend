import Base
import ./core.bend as Core
import ./lexer.bend as Lex
import ./decimal.bend as Decimal

type Parsed is Data:
  Accepted{expression: Core.Expr}
  ParseError{message: String}

type Operator is Data:
  AddOp{}
  SubtractOp{}
  NegateOp{}
  MultiplyOp{}
  DivideOp{}
  GroupFrame{outer: List<&2, Core.Expr>}
  CallFrame{name: String, arguments: List<&2, Core.Expr>, outer: List<&2, Core.Expr>}

type Stack is Data:
  Ready{operators: List<&2, Operator>, values: List<&2, Core.Expr>}
  Rejected{message: String}

def pair_args(args: List<&2, Core.Expr>) -> List<&2, Core.Expr>:
  match args:
    case a <> b <> tail:
      Core.Add{a, b} <> pair_args(tail)
    case args:
      args

# Pair adjacent arguments in rounds to produce a balanced parallel reduction.
def balanced_sum(fuel: Nat, args: List<&2, Core.Expr>) -> Parsed:
  match fuel args:
    case fuel a <> Nil{}:
      Accepted{a}
    case fuel Nil{}:
      ParseError{"SUM expects at least one argument"}
    case 0n args:
      ParseError{"Internal argument balancing limit"}
    case 1n+p args:
      balanced_sum(p, pair_args(args))

def build_if(args: List<&2, Core.Expr>) -> Parsed:
  match args:
    case c <> yes <> no <> Nil{}:
      Accepted{Core.If{c, yes, no}}
    case args:
      ParseError{"IF expects three arguments"}

def build_not(args: List<&2, Core.Expr>) -> Parsed:
  match args:
    case a <> Nil{}:
      Accepted{Core.Not{a}}
    case args:
      ParseError{"NOT expects one argument"}

def basic_call(+name: String, +args: List<&2, Core.Expr>) -> Parsed:
  Bool.pick(Parsed, String.eq(String.to_upper(name), "SUM"), balanced_sum(List.length(&2, Core.Expr, args), args), Bool.pick(Parsed, String.eq(String.to_upper(name), "IF"), build_if(args), Bool.pick(Parsed, String.eq(String.to_upper(name), "NOT"), build_not(args), ParseError{"Unknown function: " ++ name})))

def build_round(args: List<&2, Core.Expr>, mode: Decimal.Rounding) -> Parsed:
  match args:
    case value <> Nil{}:
      Accepted{Core.Round{value, Core.Literal{Core.Number{0n}}, mode}}
    case value <> places <> Nil{}:
      Accepted{Core.Round{value, places, mode}}
    case args:
      ParseError{"Rounding expects one or two arguments"}

def build_call(+name: String, +args: List<&2, Core.Expr>) -> Parsed:
  Bool.pick(Parsed, String.eq(String.to_upper(name), "ROUND"), build_round(args, Decimal.HalfAway{}), Bool.pick(Parsed, String.eq(String.to_upper(name), "ROUNDUP"), build_round(args, Decimal.TowardPositive{}), Bool.pick(Parsed, String.eq(String.to_upper(name), "ROUNDDOWN"), build_round(args, Decimal.TowardNegative{}), basic_call(name, args))))

def reduce_times(ops: List<&2, Operator>, values: List<&2, Core.Expr>) -> Stack:
  match ops values:
    case DivideOp{} <> tail right <> left <> rest:
      reduce_times(tail, Core.Divide{left, right} <> rest)
    case DivideOp{} <> tail values:
      Rejected{"Missing operand"}
    case NegateOp{} <> tail a <> rest:
      reduce_times(tail, Core.Negate{a} <> rest)
    case NegateOp{} <> tail values:
      Rejected{"Missing operand"}
    case MultiplyOp{} <> tail right <> left <> rest:
      reduce_times(tail, Core.Multiply{left, right} <> rest)
    case MultiplyOp{} <> tail values:
      Rejected{"Missing operand"}
    case ops values:
      Ready{ops, values}

def reduce_all(ops: List<&2, Operator>, values: List<&2, Core.Expr>) -> Stack:
  match ops values:
    case DivideOp{} <> tail right <> left <> rest:
      reduce_all(tail, Core.Divide{left, right} <> rest)
    case DivideOp{} <> tail values:
      Rejected{"Missing operand"}
    case NegateOp{} <> tail a <> rest:
      reduce_all(tail, Core.Negate{a} <> rest)
    case SubtractOp{} <> tail right <> left <> rest:
      reduce_all(tail, Core.Subtract{left, right} <> rest)
    case NegateOp{} <> tail values:
      Rejected{"Missing operand"}
    case SubtractOp{} <> tail values:
      Rejected{"Missing operand"}
    case MultiplyOp{} <> tail right <> left <> rest:
      reduce_all(tail, Core.Multiply{left, right} <> rest)
    case AddOp{} <> tail right <> left <> rest:
      reduce_all(tail, Core.Add{left, right} <> rest)
    case MultiplyOp{} <> tail values:
      Rejected{"Missing operand"}
    case AddOp{} <> tail values:
      Rejected{"Missing operand"}
    case ops values:
      Ready{ops, values}

def push_operator(stack: Stack, op: Operator) -> Stack:
  match stack:
    case Ready{ops, values}:
      Ready{op <> ops, values}
    case Rejected{e}:
      Rejected{e}

def call_result(result: Parsed, ops: List<&2, Operator>, outer: List<&2, Core.Expr>) -> Stack:
  match result:
    case Accepted{expr}:
      Ready{ops, expr <> outer}
    case ParseError{e}:
      Rejected{e}

def close_group(stack: Stack) -> Stack:
  match stack:
    case Ready{GroupFrame{outer} <> rest, expr <> Nil{}}:
      Ready{rest, expr <> outer}
    case Ready{CallFrame{name, args, outer} <> rest, expr <> Nil{}}:
      call_result(build_call(name, List.reverse(&2, Core.Expr, expr <> args)), rest, outer)
    case Ready{ops, values}:
      Rejected{"Unmatched closing parenthesis"}
    case Rejected{e}:
      Rejected{e}

def comma(stack: Stack) -> Stack:
  match stack:
    case Ready{CallFrame{name, args, outer} <> rest, expr <> Nil{}}:
      Ready{CallFrame{name, expr <> args, outer} <> rest, Nil{}}
    case Rejected{e}:
      Rejected{e}
    case stack:
      Rejected{"Comma outside a function argument list"}

def empty_call(stack: Stack) -> Stack:
  match stack:
    case Ready{CallFrame{name, Nil{}, outer} <> rest, Nil{}}:
      call_result(build_call(name, Nil{}), rest, outer)
    case Rejected{e}:
      Rejected{e}
    case stack:
      Rejected{"Expected an operand"}

def start_call(name: String, stack: Stack) -> Stack:
  match stack:
    case Ready{ops, outer}:
      Ready{CallFrame{name, Nil{}, outer} <> ops, Nil{}}
    case Rejected{e}:
      Rejected{e}

def identifier(+name: String) -> Core.Expr:
  Bool.pick(Core.Expr, String.eq(String.to_lower(name), "true"), Core.Literal{Core.Logical{True{}}}, Bool.pick(Core.Expr, String.eq(String.to_lower(name), "false"), Core.Literal{Core.Logical{False{}}}, Core.Variable{name}))

def operand(token: Lex.Token, stack: Stack) -> Stack:
  match token stack:
    case Lex.Minus{} stack:
      push_operator(stack, NegateOp{})
    case Lex.DecimalLiteral{n} Ready{ops, values}:
      Ready{ops, Core.Literal{Core.DecimalNumber{n}} <> values}
    case Lex.Integer{n} Ready{ops, values}:
      Ready{ops, Core.Literal{Core.Number{n}} <> values}
    case Lex.Identifier{name} Ready{ops, values}:
      Ready{ops, identifier(name) <> values}
    case Lex.LParen{} Ready{ops, values}:
      Ready{GroupFrame{values} <> ops, Nil{}}
    case Lex.RParen{} stack:
      empty_call(stack)
    case token Rejected{e}:
      Rejected{e}
    case token stack:
      Rejected{"Expected an operand"}

def operator(token: Lex.Token, stack: Stack) -> Stack:
  match token stack:
    case Lex.Slash{} Ready{ops, values}:
      push_operator(reduce_times(ops, values), DivideOp{})
    case Lex.Minus{} Ready{ops, values}:
      push_operator(reduce_all(ops, values), SubtractOp{})
    case Lex.Plus{} Ready{ops, values}:
      push_operator(reduce_all(ops, values), AddOp{})
    case Lex.Times{} Ready{ops, values}:
      push_operator(reduce_times(ops, values), MultiplyOp{})
    case Lex.RParen{} Ready{ops, values}:
      close_group(reduce_all(ops, values))
    case Lex.Comma{} Ready{ops, values}:
      comma(reduce_all(ops, values))
    case token Rejected{e}:
      Rejected{e}
    case token stack:
      Rejected{"Expected an operator"}

def next_expectation(token: Lex.Token) -> Bool:
  match token:
    case Lex.DecimalLiteral{n}:
      False{}
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
  match tokens expected:
    case Lex.Identifier{name} <> Lex.LParen{} <> tail True{}:
      scan(tail, start_call(name, stack), True{})
    case Nil{} expected:
      finish(expected, stack)
    case +head <> tail expected:
      scan(tail, step(expected, head, stack), next_expectation(head))

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
