import Base
import ./core.bend as Core
import ./lexer.bend as Lex
import ./decimal.bend as Decimal
import ./inspect.bend as Inspect
import ./dependencies.bend as Dependencies

type Parsed is Data:
  Accepted{expression: Core.Expr}
  ParseError{message: String}

type Operator is Data:
  AddOp{}
  SubtractOp{}
  NegateOp{}
  MultiplyOp{}
  DivideOp{}
  CompareOp{operation: Core.Comparison}
  AndOp{}
  OrOp{}
  XorOp{}
  PrefixNotOp{}
  GroupFrame{outer: List<&2, Core.Expr>}
  CallFrame{name: String, arguments: List<&2, Core.Expr>, outer: List<&2, Core.Expr>}
  ArrayFrame{elements: List<&2, Core.Expr>, outer: List<&2, Core.Expr>}
  IndexFrame{structure: Core.Expr, outer: List<&2, Core.Expr>}

type Stack is Data:
  ParseReady{operators: List<&2, Operator>, values: List<&2, Core.Expr>}
  Rejected{message: String}

def wrap_args(args: List<&2, Core.Expr>, +validation: Core.ArgumentValidation) -> List<&2, Core.Expr>:
  match args:
    case Nil{}:
      Nil{}
    case head <> tail:
      Core.Argument{head, validation} <> wrap_args(tail, validation)

def pair_args(args: List<&2, Core.Expr>) -> List<&2, Core.Expr>:
  match args:
    case a <> b <> rest:
      Core.Arguments{a, b} <> pair_args(rest)
    case args:
      args

def balanced_arguments(fuel: Nat, args: List<&2, Core.Expr>) -> Parsed:
  match fuel args:
    case fuel Nil{}:
      Accepted{Core.EmptyArguments{}}
    case fuel a <> Nil{}:
      Accepted{a}
    case 0n args:
      ParseError{"Internal argument balancing limit"}
    case 1n+p args:
      balanced_arguments(p, pair_args(args))

def function_tree(tree: Parsed, kind: Core.FunctionKind) -> Parsed:
  match tree:
    case Accepted{arguments}:
      Accepted{Core.FunctionCall{kind, arguments}}
    case ParseError{e}:
      ParseError{e}

def build_function(+args: List<&2, Core.Expr>, kind: Core.FunctionKind, validation: Core.ArgumentValidation) -> Parsed:
  function_tree(balanced_arguments(List.length(&2, Core.Expr, args), wrap_args(args, validation)), kind)

def array_tree(tree: Parsed) -> Parsed:
  match tree:
    case Accepted{elements}:
      Accepted{Core.ArrayLiteral{elements}}
    case ParseError{e}:
      ParseError{e}

def build_array(+args: List<&2, Core.Expr>) -> Parsed:
  array_tree(balanced_arguments(List.length(&2, Core.Expr, args), wrap_args(args, Core.RawArgument{})))

def build_xor(args: List<&2, Core.Expr>) -> Parsed:
  match args:
    case Nil{}:
      ParseError{"XOR expects at least one argument"}
    case args:
      build_function(args, Core.XorFunction{}, Core.LogicalArgument{})

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

def build_abs(args: List<&2, Core.Expr>) -> Parsed:
  match args:
    case a <> Nil{}:
      build_function([a], Core.AbsFunction{}, Core.RawArgument{})
    case args:
      ParseError{"ABS expects one argument"}

def legacy_call(+name: String, +args: List<&2, Core.Expr>) -> Parsed:
  Bool.pick(Parsed, String.eq(String.to_upper(name), "SUM"), build_function(args, Core.SumFunction{}, Core.RawArgument{}), Bool.pick(Parsed, String.eq(String.to_upper(name), "IF"), build_if(args), Bool.pick(Parsed, String.eq(String.to_upper(name), "NOT"), build_not(args), ParseError{"Unknown function: " ++ name})))

def choose_call(matches: Bool, yes: Unit -> Parsed, no: Unit -> Parsed) -> Parsed:
  match matches:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def logical_call(+name: String, +args: List<&2, Core.Expr>) -> Parsed:
  choose_call(String.eq(String.to_upper(name), "AND"), u => build_function(args, Core.AndFunction{}, Core.RawArgument{}), u => choose_call(String.eq(String.to_upper(name), "OR"), u => build_function(args, Core.OrFunction{}, Core.RawArgument{}), u => choose_call(String.eq(String.to_upper(name), "XOR"), u => build_xor(args), u => legacy_call(name, args))))

def basic_call(+name: String, +args: List<&2, Core.Expr>) -> Parsed:
  choose_call(String.eq(String.to_upper(name), "COUNT"), u => build_function(args, Core.CountFunction{}, Core.RawArgument{}), u => choose_call(String.eq(String.to_upper(name), "MUL"), u => build_function(args, Core.ProductFunction{}, Core.RawArgument{}), u => choose_call(String.eq(String.to_upper(name), "MIN"), u => build_function(args, Core.MinFunction{}, Core.RawArgument{}), u => choose_call(String.eq(String.to_upper(name), "MAX"), u => build_function(args, Core.MaxFunction{}, Core.RawArgument{}), u => choose_call(String.eq(String.to_upper(name), "AVG"), u => build_function(args, Core.AverageFunction{}, Core.RawArgument{}), u => choose_call(String.eq(String.to_upper(name), "ABS"), u => build_abs(args), u => logical_call(name, args)))))))

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

def precedence(op: Operator) -> Nat:
  match op:
    case NegateOp{}:
      40n
    case MultiplyOp{}:
      20n
    case DivideOp{}:
      20n
    case AddOp{}:
      10n
    case SubtractOp{}:
      10n
    case CompareOp{kind}:
      5n
    case PrefixNotOp{}:
      3n
    case op:
      0n

def reducible(op: Operator) -> Bool:
  match op:
    case ArrayFrame{elements, outer}:
      False{}
    case IndexFrame{structure, outer}:
      False{}
    case GroupFrame{outer}:
      False{}
    case CallFrame{name, args, outer}:
      False{}
    case op:
      True{}

def reduce_one(op: Operator, tail: List<&2, Operator>, values: List<&2, Core.Expr>) -> Stack:
  match op values:
    case NegateOp{} a <> rest:
      ParseReady{tail, Core.Negate{a} <> rest}
    case PrefixNotOp{} a <> rest:
      ParseReady{tail, Core.PrefixNot{a} <> rest}
    case MultiplyOp{} right <> left <> rest:
      ParseReady{tail, Core.Multiply{left, right} <> rest}
    case DivideOp{} right <> left <> rest:
      ParseReady{tail, Core.Divide{left, right} <> rest}
    case AddOp{} right <> left <> rest:
      ParseReady{tail, Core.Add{left, right} <> rest}
    case SubtractOp{} right <> left <> rest:
      ParseReady{tail, Core.Subtract{left, right} <> rest}
    case CompareOp{kind} right <> left <> rest:
      ParseReady{tail, Core.Compare{kind, left, right} <> rest}
    case AndOp{} right <> left <> rest:
      ParseReady{tail, Core.And{left, right} <> rest}
    case OrOp{} right <> left <> rest:
      ParseReady{tail, Core.Or{left, right} <> rest}
    case XorOp{} right <> left <> rest:
      ParseReady{tail, Core.Xor{left, right} <> rest}
    case op values:
      Rejected{"Missing operand"}

def reduced_values(result: Stack, next: List<&2, Core.Expr> -> Stack) -> Stack:
  match result:
    case ParseReady{ops, values}:
      next(values)
    case Rejected{e}:
      Rejected{e}

def reduce_decision(proceed: Bool, done: Unit -> Stack, next: Unit -> Stack) -> Stack:
  match proceed:
    case False{}:
      done(Unit{})
    case True{}:
      next(Unit{})

def reduce_to(ops: List<&2, Operator>, +values: List<&2, Core.Expr>, +minimum: Nat) -> Stack:
  match ops:
    case Nil{}:
      ParseReady{Nil{}, values}
    case +head <> +tail:
      reduce_decision(Bool.and(reducible(head), Nat.is_ge(precedence(head), minimum)), u => ParseReady{head <> tail, values}, u => reduced_values(reduce_one(head, tail, values), v => reduce_to(tail, v, minimum)))

def reduce_times(ops: List<&2, Operator>, values: List<&2, Core.Expr>) -> Stack:
  reduce_to(ops, values, 20n)

def reduce_arithmetic(ops: List<&2, Operator>, values: List<&2, Core.Expr>) -> Stack:
  reduce_to(ops, values, 10n)

def reduce_comparisons(ops: List<&2, Operator>, values: List<&2, Core.Expr>) -> Stack:
  reduce_to(ops, values, 5n)

def reduce_all(ops: List<&2, Operator>, values: List<&2, Core.Expr>) -> Stack:
  reduce_to(ops, values, 0n)

def push_operator(stack: Stack, op: Operator) -> Stack:
  match stack:
    case ParseReady{ops, values}:
      ParseReady{op <> ops, values}
    case Rejected{e}:
      Rejected{e}

def call_result(result: Parsed, ops: List<&2, Operator>, outer: List<&2, Core.Expr>) -> Stack:
  match result:
    case Accepted{expr}:
      ParseReady{ops, expr <> outer}
    case ParseError{e}:
      Rejected{e}

def close_group(stack: Stack) -> Stack:
  match stack:
    case ParseReady{GroupFrame{outer} <> rest, expr <> Nil{}}:
      ParseReady{rest, expr <> outer}
    case ParseReady{CallFrame{name, args, outer} <> rest, expr <> Nil{}}:
      call_result(build_call(name, List.reverse(&2, Core.Expr, expr <> args)), rest, outer)
    case ParseReady{ops, values}:
      Rejected{"Unmatched closing parenthesis"}
    case Rejected{e}:
      Rejected{e}

def comma(stack: Stack) -> Stack:
  match stack:
    case ParseReady{ArrayFrame{args, outer} <> rest, expr <> Nil{}}:
      ParseReady{ArrayFrame{expr <> args, outer} <> rest, Nil{}}
    case ParseReady{CallFrame{name, args, outer} <> rest, expr <> Nil{}}:
      ParseReady{CallFrame{name, expr <> args, outer} <> rest, Nil{}}
    case Rejected{e}:
      Rejected{e}
    case stack:
      Rejected{"Comma outside a function argument list"}

def empty_call(stack: Stack) -> Stack:
  match stack:
    case ParseReady{CallFrame{name, Nil{}, outer} <> rest, Nil{}}:
      call_result(build_call(name, Nil{}), rest, outer)
    case Rejected{e}:
      Rejected{e}
    case stack:
      Rejected{"Expected an operand"}

def start_call(name: String, stack: Stack) -> Stack:
  match stack:
    case ParseReady{ops, outer}:
      ParseReady{CallFrame{name, Nil{}, outer} <> ops, Nil{}}
    case Rejected{e}:
      Rejected{e}

def close_array(stack: Stack) -> Stack:
  match stack:
    case ParseReady{ArrayFrame{args, outer} <> rest, expr <> Nil{}}:
      call_result(build_array(List.reverse(&2, Core.Expr, expr <> args)), rest, outer)
    case Rejected{e}:
      Rejected{e}
    case stack:
      Rejected{"Unmatched closing brace"}

def empty_array(stack: Stack) -> Stack:
  match stack:
    case ParseReady{ArrayFrame{Nil{}, outer} <> rest, Nil{}}:
      ParseReady{rest, Core.ArrayLiteral{Core.EmptyArguments{}} <> outer}
    case Rejected{e}:
      Rejected{e}
    case stack:
      Rejected{"Expected an array element"}

# The pinned parser uses a global output stack. An empty array consumes a
# previous operand when one exists, leaving too few operands for its parent.
def prior_output(ops: List<&2, Operator>) -> Bool:
  match ops:
    case Nil{}:
      False{}
    case CallFrame{name, args, outer} <> rest:
      Bool.or(Bool.not(List.is_empty(&2, Core.Expr, args)), Bool.or(Bool.not(List.is_empty(&2, Core.Expr, outer)), prior_output(rest)))
    case ArrayFrame{args, outer} <> rest:
      Bool.or(Bool.not(List.is_empty(&2, Core.Expr, args)), Bool.or(Bool.not(List.is_empty(&2, Core.Expr, outer)), prior_output(rest)))
    case GroupFrame{outer} <> rest:
      Bool.or(Bool.not(List.is_empty(&2, Core.Expr, outer)), prior_output(rest))
    case IndexFrame{structure, outer} <> rest:
      True{}
    case op <> rest:
      prior_output(rest)

def checked_empty_array(prior: Bool, stack: Stack) -> Stack:
  match prior:
    case True{}:
      Rejected{"Empty array consumed a preceding operand"}
    case False{}:
      empty_array(stack)

def empty_array_compatible(+stack: Stack) -> Stack:
  match stack:
    case ParseReady{ops, values}:
      checked_empty_array(prior_output(ops), stack)
    case Rejected{e}:
      Rejected{e}

def close_index(stack: Stack) -> Stack:
  match stack:
    case ParseReady{IndexFrame{structure, outer} <> rest, index <> Nil{}}:
      ParseReady{rest, Core.Access{structure, index} <> outer}
    case Rejected{e}:
      Rejected{e}
    case stack:
      Rejected{"Unmatched closing bracket"}

def identifier(+name: String) -> Core.Expr:
  Bool.pick(Core.Expr, String.eq(String.to_lower(name), "true"), Core.Literal{Core.Logical{True{}}}, Bool.pick(Core.Expr, String.eq(String.to_lower(name), "false"), Core.Literal{Core.Logical{False{}}}, Bool.pick(Core.Expr, String.eq(String.to_lower(name), "null"), Core.Literal{Core.NullValue{}}, Core.Variable{name})))

def keyword_operand(+name: String, stack: Stack) -> Stack:
  match stack:
    case ParseReady{ops, values}:
      Bool.pick(Stack, Bool.or(String.eq(name, "&&"), String.eq(name, "||")), Rejected{"Expected an operand"}, ParseReady{ops, Core.Variable{name} <> values})
    case Rejected{e}:
      Rejected{e}

def operand(token: Lex.Token, stack: Stack) -> Stack:
  match token stack:
    case Lex.LBrace{} ParseReady{ops, values}:
      ParseReady{ArrayFrame{Nil{}, values} <> ops, Nil{}}
    case Lex.RBrace{} stack:
      empty_array_compatible(stack)
    case Lex.NotWord{name} stack:
      push_operator(stack, PrefixNotOp{})
    case Lex.BangWord{} stack:
      push_operator(stack, PrefixNotOp{})
    case Lex.AndWord{name} stack:
      keyword_operand(name, stack)
    case Lex.OrWord{name} stack:
      keyword_operand(name, stack)
    case Lex.XorWord{name} stack:
      keyword_operand(name, stack)
    case Lex.StringLiteral{s} ParseReady{ops, values}:
      ParseReady{ops, Core.Literal{Core.TextValue{s}} <> values}
    case Lex.Minus{} stack:
      push_operator(stack, NegateOp{})
    case Lex.DecimalLiteral{n} ParseReady{ops, values}:
      ParseReady{ops, Core.Literal{Core.DecimalNumber{n}} <> values}
    case Lex.Integer{n} ParseReady{ops, values}:
      ParseReady{ops, Core.Literal{Core.Number{n}} <> values}
    case Lex.Identifier{name} ParseReady{ops, values}:
      ParseReady{ops, identifier(name) <> values}
    case Lex.LParen{} ParseReady{ops, values}:
      ParseReady{GroupFrame{values} <> ops, Nil{}}
    case Lex.RParen{} stack:
      empty_call(stack)
    case token Rejected{e}:
      Rejected{e}
    case token stack:
      Rejected{"Expected an operand"}

def operator(token: Lex.Token, stack: Stack) -> Stack:
  match token stack:
    case Lex.LBracket{} ParseReady{ops, structure <> outer}:
      ParseReady{IndexFrame{structure, outer} <> ops, Nil{}}
    case Lex.RBracket{} ParseReady{ops, values}:
      close_index(reduce_all(ops, values))
    case Lex.RBrace{} ParseReady{ops, values}:
      close_array(reduce_all(ops, values))
    case Lex.AndWord{name} ParseReady{ops, values}:
      push_operator(reduce_all(ops, values), AndOp{})
    case Lex.OrWord{name} ParseReady{ops, values}:
      push_operator(reduce_all(ops, values), OrOp{})
    case Lex.XorWord{name} ParseReady{ops, values}:
      push_operator(reduce_all(ops, values), XorOp{})
    case Lex.EqualToken{} ParseReady{ops, values}:
      push_operator(reduce_comparisons(ops, values), CompareOp{Core.EqualTo{}})
    case Lex.NotEqualToken{} ParseReady{ops, values}:
      push_operator(reduce_comparisons(ops, values), CompareOp{Core.NotEqualTo{}})
    case Lex.LessToken{} ParseReady{ops, values}:
      push_operator(reduce_comparisons(ops, values), CompareOp{Core.LessThan{}})
    case Lex.LessEqualToken{} ParseReady{ops, values}:
      push_operator(reduce_comparisons(ops, values), CompareOp{Core.LessOrEqual{}})
    case Lex.GreaterToken{} ParseReady{ops, values}:
      push_operator(reduce_comparisons(ops, values), CompareOp{Core.GreaterThan{}})
    case Lex.GreaterEqualToken{} ParseReady{ops, values}:
      push_operator(reduce_comparisons(ops, values), CompareOp{Core.GreaterOrEqual{}})
    case Lex.Slash{} ParseReady{ops, values}:
      push_operator(reduce_times(ops, values), DivideOp{})
    case Lex.Minus{} ParseReady{ops, values}:
      push_operator(reduce_arithmetic(ops, values), SubtractOp{})
    case Lex.Plus{} ParseReady{ops, values}:
      push_operator(reduce_arithmetic(ops, values), AddOp{})
    case Lex.Times{} ParseReady{ops, values}:
      push_operator(reduce_times(ops, values), MultiplyOp{})
    case Lex.RParen{} ParseReady{ops, values}:
      close_group(reduce_all(ops, values))
    case Lex.Comma{} ParseReady{ops, values}:
      comma(reduce_all(ops, values))
    case token Rejected{e}:
      Rejected{e}
    case token stack:
      Rejected{"Expected an operator"}

def ordinary_expectation(token: Lex.Token) -> Bool:
  match token:
    case Lex.RBrace{}:
      False{}
    case Lex.RBracket{}:
      False{}
    case Lex.StringLiteral{s}:
      False{}
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

def next_expectation(token: Lex.Token, was_operand: Bool) -> Bool:
  match token:
    case Lex.AndWord{name}:
      Bool.not(was_operand)
    case Lex.OrWord{name}:
      Bool.not(was_operand)
    case Lex.XorWord{name}:
      Bool.not(was_operand)
    case token:
      ordinary_expectation(token)

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
    case Lex.NotWord{name} <> Lex.LParen{} <> tail True{}:
      scan(tail, start_call(name, stack), True{})
    case Lex.AndWord{name} <> Lex.LParen{} <> tail True{}:
      scan(tail, start_call(name, stack), True{})
    case Lex.OrWord{name} <> Lex.LParen{} <> tail True{}:
      scan(tail, start_call(name, stack), True{})
    case Lex.XorWord{name} <> Lex.LParen{} <> tail True{}:
      scan(tail, start_call(name, stack), True{})
    case Lex.Identifier{name} <> Lex.LParen{} <> tail True{}:
      scan(tail, start_call(name, stack), True{})
    case Nil{} expected:
      finish(expected, stack)
    case +head <> tail +expected:
      scan(tail, step(expected, head, stack), next_expectation(head, expected))

def validated(info: Inspect.Info, expr: Core.Expr) -> Parsed:
  match info:
    case Inspect.Metadata{kind, dynamic, True{}}:
      Accepted{expr}
    case Inspect.Metadata{kind, dynamic, False{}}:
      ParseError{"Invalid static operand type"}

def completed(stack: Stack) -> Parsed:
  match stack:
    case ParseReady{Nil{}, +expr <> Nil{}}:
      validated(Inspect.analyze(expr), expr)
    case ParseReady{ops, values}:
      ParseError{"Unmatched parenthesis or missing operand"}
    case Rejected{e}:
      ParseError{e}

def drain(stack: Stack) -> Parsed:
  match stack:
    case ParseReady{ArrayFrame{a <> Nil{}, outer} <> rest, b <> Nil{}}:
      # At EOF upstream consumes the default binary arity of an open array.
      completed(close_array(ParseReady{ArrayFrame{[a], outer} <> rest, [b]}))
    case ParseReady{ops, values}:
      completed(reduce_all(ops, values))
    case Rejected{e}:
      ParseError{e}

def balanced_parentheses(tokens: List<&2, Lex.Token>, depth: Nat) -> Bool:
  match tokens depth:
    case Nil{} depth:
      Nat.is_eq(depth, 0n)
    case Lex.LParen{} <> rest depth:
      balanced_parentheses(rest, 1n+depth)
    case Lex.RParen{} <> rest 0n:
      False{}
    case Lex.RParen{} <> rest 1n+p:
      balanced_parentheses(rest, p)
    case head <> rest depth:
      balanced_parentheses(rest, depth)

def parse_tokens(balanced: Bool, tokens: List<&2, Lex.Token>) -> Parsed:
  match balanced:
    case True{}:
      drain(scan(tokens, ParseReady{Nil{}, Nil{}}, True{}))
    case False{}:
      ParseError{"Tokenizer: unbalanced parentheses"}

def parse(source: String) -> Parsed:
  +tokens = Lex.tokenize(source)
  parse_tokens(balanced_parentheses(tokens, 0n), tokens)

def preflight(missing: List<&2, String>, expr: Core.Expr, context: List<&2, Core.Binding>, sensitive: Bool) -> Core.Value:
  match missing:
    case Nil{}:
      Core.evaluate_in(expr, context, sensitive)
    case names:
      Core.Failure{"Unbound variable: " ++ String.join(Dependencies.unique(names, Nil{}), ", ")}

def evaluate_checked(+expr: Core.Expr, +context: List<&2, Core.Binding>, +sensitive: Bool) -> Core.Value:
  preflight(Dependencies.analyze(expr, context, sensitive, False{}), expr, context, sensitive)

def evaluate_parsed(parsed: Parsed, context: List<&2, Core.Binding>, sensitive: Bool) -> Core.Value:
  match parsed:
    case Accepted{expr}:
      evaluate_checked(expr, context, sensitive)
    case ParseError{e}:
      Core.Failure{"Parse error: " ++ e}

def evaluate(source: String, context: List<&2, Core.Binding>, sensitive: Bool) -> Core.Value:
  evaluate_parsed(parse(source), context, sensitive)

# Differential snapshots preserve parse-error classification before evaluation.
def snapshot_parsed(parsed: Parsed, context: List<&2, Core.Binding>, sensitive: Bool) -> String:
  match parsed:
    case Accepted{expr}:
      Core.snapshot(evaluate_checked(expr, context, sensitive))
    case ParseError{e}:
      Bool.pick(String, String.starts_with(e, "Tokenizer: "), "error:Dentaku::TokenizerError", "error:Dentaku::ParseError")

def snapshot(source: String, context: List<&2, Core.Binding>, sensitive: Bool) -> String:
  snapshot_parsed(parse(source), context, sensitive)

type NamesResult is Data:
  FoundNames{names: List<&2, String>}
  NamesError{message: String}

def names_mode(names: List<&2, String>, static: Bool) -> NamesResult:
  match static:
    case True{}:
      FoundNames{Dependencies.unique(names, Nil{})}
    case False{}:
      FoundNames{names}

def names_result(parsed: Parsed, context: List<&2, Core.Binding>, sensitive: Bool, +static: Bool) -> NamesResult:
  match parsed:
    case Accepted{expr}:
      names_mode(Dependencies.analyze(expr, context, sensitive, static), static)
    case ParseError{e}:
      NamesError{e}

def identifiers(source: String, sensitive: Bool) -> NamesResult:
  names_result(parse(source), Nil{}, sensitive, True{})

def dependencies(source: String, context: List<&2, Core.Binding>, sensitive: Bool) -> NamesResult:
  names_result(parse(source), context, sensitive, False{})

def names_snapshot(result: NamesResult) -> String:
  match result:
    case FoundNames{names}:
      "names:" ++ String.join(names, ",")
    case NamesError{e}:
      Bool.pick(String, String.starts_with(e, "Tokenizer: "), "error:Dentaku::TokenizerError", "error:Dentaku::ParseError")
