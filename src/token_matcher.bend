import Base
import ./core.bend as Core
import ./token.bend as Token

# Immutable counterpart of Dentaku::TokenMatcher. Modifiers return a new rule;
# sharing a rule never models Ruby's mutable aliasing.
type Predicate is Data:
  Never{}
  Leaf{categories: Core.Value, values: Core.Value, inverted: Bool}
  Choice{left: Predicate, right: Predicate}

type Matcher is Data:
  Rule{categories: Core.Value, values: Core.Value, children: List<&2, Matcher>, predicate: Predicate, inverted: Bool, anchored: Bool, minimum: Nat, repeated: Bool}

type MatchResult is Data:
  Matched{accepted: Bool, tokens: List<&2, Token.Token>}

def flatten(value: Core.Value) -> Core.Value:
  match value:
    case Core.ArrayNil{}:
      Core.ArrayNil{}
    case Core.ArrayCons{head, tail}:
      a b = flatten(head) flatten(tail)
      Core.array_append(a, b)
    case value:
      Core.ArrayCons{value, Core.ArrayNil{}}

def unique_keys(values: Core.Value, +seen: Core.Value) -> Core.Value:
  match values:
    case Core.ArrayCons{+head, tail}:
      unique_keys(tail, Bool.pick(Core.Value, Core.set_contains(seen, head, True{}), seen, Core.array_append(seen, Core.ArrayCons{head, Core.ArrayNil{}})))
    case values:
      seen

# Compact happens before flatten: a nested nil remains a real hash key.
def keys(value: Core.Value) -> Core.Value:
  match value:
    case Core.NullValue{}:
      Core.ArrayNil{}
    case value:
      unique_keys(flatten(value), Core.ArrayNil{})

def is_no_children(children: List<&2, Matcher>) -> Bool:
  match children:
    case Nil{}:
      True{}
    case children:
      False{}

def get_predicate(matcher: Matcher) -> Predicate:
  match matcher:
    case Rule{categories, values, children, predicate, inverted, anchored, minimum, repeated}:
      predicate

def child_predicate(children: List<&2, Matcher>) -> Predicate:
  match children:
    case Nil{}:
      Never{}
    case head <> tail:
      a b = get_predicate(head) child_predicate(tail)
      Choice{a, b}

def choose_predicate(leaf: Bool, a: Predicate, b: Predicate) -> Predicate:
  Bool.pick(Predicate, leaf, a, b)

def make(categories: Core.Value, values: Core.Value, +children: List<&2, Matcher>) -> Matcher:
  +cats = keys(categories)
  +vals = keys(values)
  +predicate = child_predicate(children)
  Rule{cats, vals, children, choose_predicate(is_no_children(children), Leaf{cats, vals, False{}}, predicate), False{}, False{}, 1n, False{}}

def invert(matcher: Matcher) -> Matcher:
  match matcher:
    case Rule{+categories, +values, +children, predicate, +inverted, anchored, minimum, repeated}:
      Rule{categories, values, children, choose_predicate(is_no_children(children), Leaf{categories, values, Bool.not(inverted)}, predicate), Bool.not(inverted), anchored, minimum, repeated}

def caret(matcher: Matcher) -> Matcher:
  match matcher:
    case Rule{categories, values, children, predicate, inverted, anchored, minimum, repeated}:
      Rule{categories, values, children, predicate, inverted, True{}, minimum, repeated}

def star(matcher: Matcher) -> Matcher:
  match matcher:
    case Rule{categories, values, children, predicate, inverted, anchored, minimum, repeated}:
      Rule{categories, values, children, predicate, inverted, anchored, 0n, True{}}

def plus(matcher: Matcher) -> Matcher:
  match matcher:
    case Rule{categories, values, children, predicate, inverted, anchored, minimum, repeated}:
      Rule{categories, values, children, predicate, inverted, anchored, minimum, True{}}

def leaf_matchers(+matcher: Matcher) -> List<&2, Matcher>:
  match matcher:
    case Rule{categories, values, Nil{}, predicate, inverted, anchored, minimum, repeated}:
      matcher <> Nil{}
    case Rule{categories, values, children, predicate, inverted, anchored, minimum, repeated}:
      children

def append(left: List<&2, Matcher>, right: List<&2, Matcher>) -> List<&2, Matcher>:
  match left:
    case Nil{}:
      right
    case head <> tail:
      head <> append(tail, right)

def either(left: Matcher, right: Matcher) -> Matcher:
  make(Core.SymbolValue{"nomatch"}, Core.SymbolValue{"nomatch"}, append(leaf_matchers(left), leaf_matchers(right)))

def accepts_key(keys: Core.Value, +value: Core.Value) -> Bool:
  match keys:
    case Core.ArrayNil{}:
      True{}
    case keys:
      Core.set_contains(keys, value, True{})

def accepts_predicate(predicate: Predicate, +token: Maybe<&2, Token.Token>) -> Bool:
  match predicate:
    case Never{}:
      False{}
    case Leaf{categories, values, inverted}:
      match token:
        case None{}:
          False{}
        case Some{Token.Lexeme{category, value, raw}}:
          a b = accepts_key(categories, category) accepts_key(values, value)
          Bool.not(Cmp.is_eq(Bool.cmp(Bool.and(a, b), inverted)))
    case Choice{left, right}:
      a b = accepts_predicate(left, token) accepts_predicate(right, token)
      Bool.or(a, b)

def accepts(matcher: Matcher, token: Maybe<&2, Token.Token>) -> Bool:
  accepts_predicate(get_predicate(matcher), token)

def get_caret(matcher: Matcher) -> Bool:
  match matcher:
    case Rule{categories, values, children, predicate, inverted, anchored, minimum, repeated}:
      anchored

def is_leaf(matcher: Matcher) -> Bool:
  match matcher:
    case Rule{categories, values, Nil{}, predicate, inverted, anchored, minimum, repeated}:
      True{}
    case matcher:
      False{}

def stream_length(stream: List<&2, Maybe<&2, Token.Token>>) -> Nat:
  match stream:
    case Nil{}:
      0n
    case head <> tail:
      Nat.add(1n, stream_length(tail))

def drop(stream: List<&2, Maybe<&2, Token.Token>>, count: Nat) -> List<&2, Maybe<&2, Token.Token>>:
  match stream count:
    case stream 0n:
      stream
    case Nil{} count:
      Nil{}
    case head <> tail count:
      drop(tail, Nat.sub(count, 1n))

def stream_append(left: List<&2, Maybe<&2, Token.Token>>, right: List<&2, Maybe<&2, Token.Token>>) -> List<&2, Maybe<&2, Token.Token>>:
  match left:
    case Nil{}:
      right
    case head <> tail:
      head <> stream_append(tail, right)

# Ruby Array indexing moves from negative indices to zero, then to its end.
# This finite expansion contains at most twice the input length.
def starting_negative(inside: Bool, +stream: List<&2, Maybe<&2, Token.Token>>, offset: Nat, length: Nat) -> List<&2, Maybe<&2, Token.Token>>:
  match inside:
    case False{}:
      Nil{}
    case True{}:
      stream_append(drop(stream, Nat.sub(length, offset)), stream)

def starting_stream(+stream: List<&2, Maybe<&2, Token.Token>>, negative: Bool, +offset: Nat) -> List<&2, Maybe<&2, Token.Token>>:
  match negative:
    case False{}:
      drop(stream, offset)
    case True{}:
      +length = stream_length(stream)
      starting_negative(Nat.is_le(offset, length), stream, offset, length)

def collect_tail(repeated: Bool, next: Unit -> List<&2, Token.Token>) -> List<&2, Token.Token>:
  match repeated:
    case False{}:
      Nil{}
    case True{}:
      next(Unit{})

def collect_accepted(accepted: Bool, token: Token.Token, next: Unit -> List<&2, Token.Token>) -> List<&2, Token.Token>:
  match accepted:
    case False{}:
      Nil{}
    case True{}:
      token <> next(Unit{})

def collect(+matcher: Matcher, stream: List<&2, Maybe<&2, Token.Token>>, repeated: Bool) -> List<&2, Token.Token>:
  match stream:
    case Nil{}:
      Nil{}
    case None{} <> tail:
      Nil{}
    case Some{+token} <> tail:
      collect_accepted(accepts(matcher, Some{token}), token, u => collect_tail(repeated, v => collect(matcher, tail, True{})))

def token_count(tokens: List<&2, Token.Token>) -> Nat:
  match tokens:
    case Nil{}:
      0n
    case head <> tail:
      Nat.add(1n, token_count(tail))

def match_stream(+matcher: Matcher, stream: List<&2, Maybe<&2, Token.Token>>, negative: Bool, offset: Nat) -> MatchResult:
  match matcher:
    case Rule{categories, values, children, predicate, inverted, anchored, minimum, repeated}:
      +tokens = collect(matcher, starting_stream(stream, negative, offset), repeated)
      Matched{Nat.is_le(minimum, token_count(tokens)), tokens}

def category(name: String) -> Matcher:
  make(Core.SymbolValue{name}, Core.NullValue{}, Nil{})

def selected(name: String, value: String) -> Matcher:
  make(Core.SymbolValue{name}, Core.SymbolValue{value}, Nil{})

def pair(name: String, left: String, right: String) -> Matcher:
  make(Core.SymbolValue{name}, Core.ArrayCons{Core.SymbolValue{left}, Core.ArrayCons{Core.SymbolValue{right}, Core.ArrayNil{}}}, Nil{})

def builtin(name: String) -> Matcher:
  match name:
    case "value":
      either(either(category("datetime"), category("numeric")), either(category("string"), category("logical")))
    case "addsub":
      pair("operator", "add", "subtract")
    case "subtract":
      selected("operator", "subtract")
    case "anchored_minus":
      caret(selected("operator", "subtract"))
    case "muldiv":
      pair("operator", "multiply", "divide")
    case "pow":
      selected("operator", "pow")
    case "mod":
      selected("operator", "mod")
    case "comp_gt":
      pair("comparator", "gt", "ge")
    case "comp_lt":
      pair("comparator", "lt", "le")
    case "open":
      selected("grouping", "open")
    case "close":
      selected("grouping", "close")
    case "comma":
      selected("grouping", "comma")
    case "non_group":
      invert(category("grouping"))
    case "non_group_star":
      star(invert(category("grouping")))
    case "non_close_plus":
      plus(invert(selected("grouping", "close")))
    case "arguments":
      plus(either(either(either(category("datetime"), category("numeric")), either(category("string"), category("logical"))), selected("grouping", "comma")))
    case "if":
      selected("function", "if")
    case "round":
      selected("function", "round")
    case "roundup":
      selected("function", "roundup")
    case "rounddown":
      selected("function", "rounddown")
    case "not":
      selected("function", "not")
    case name:
      category(name)
def get_categories(matcher: Matcher) -> Core.Value:
  match matcher:
    case Rule{categories, values, children, predicate, inverted, anchored, minimum, repeated}:
      categories

def get_values(matcher: Matcher) -> Core.Value:
  match matcher:
    case Rule{categories, values, children, predicate, inverted, anchored, minimum, repeated}:
      values

def get_minimum(matcher: Matcher) -> Nat:
  match matcher:
    case Rule{categories, values, children, predicate, inverted, anchored, minimum, repeated}:
      minimum
# The parameter is a Value: Dentaku also accepts String names, nil wildcards,
# arrays of names and other supported Hash keys.
def for_function(name: Core.Value) -> Matcher:
  make(Core.SymbolValue{"function"}, name, Nil{})
