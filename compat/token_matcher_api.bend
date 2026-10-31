import Base
import ../src/core.bend as Core
import ../src/decimal.bend as Decimal
import ../src/token.bend as Token
import ../src/token_matcher.bend as Matcher
import ./token_api.bend as TokenApi

# Bottom-up structural fold: nested descriptors have no arbitrary depth limit.
type Field is Data:
  Entry{key: Core.Value, matchers: List<&2, Matcher.Matcher>}

type Parsed is Data:
  Node{raw: Core.Value, matcher: Matcher.Matcher, items: List<&2, Matcher.Matcher>, fields: List<&2, Field>}

def field(input: Core.Value, name: String) -> Core.Value:
  Core.hash_get(input, Core.SymbolValue{name})

def field_pick(found: Bool, yes: List<&2, Matcher.Matcher>, no: List<&2, Matcher.Matcher>) -> List<&2, Matcher.Matcher>:
  Bool.pick(List<&2, Matcher.Matcher>, found, yes, no)

def field_items(fields: List<&2, Field>, +name: String) -> List<&2, Matcher.Matcher>:
  match fields:
    case Nil{}:
      Nil{}
    case Entry{key, values} <> tail:
      field_pick(Core.hash_key_equal(key, Core.SymbolValue{name}), values, field_items(tail, name))

def modifiers(values: Core.Value, matcher: Matcher.Matcher) -> Matcher.Matcher:
  match values:
    case Core.ArrayCons{Core.TextValue{name}, tail}:
      match name:
        case "invert":
          modifiers(tail, Matcher.invert(matcher))
        case "caret":
          modifiers(tail, Matcher.caret(matcher))
        case "star":
          modifiers(tail, Matcher.star(matcher))
        case "plus":
          modifiers(tail, Matcher.plus(matcher))
        case name:
          modifiers(tail, matcher)
    case values:
      matcher

def alternatives(values: List<&2, Matcher.Matcher>, matcher: Matcher.Matcher) -> Matcher.Matcher:
  match values:
    case head <> tail:
      alternatives(tail, Matcher.either(matcher, head))
    case Nil{}:
      matcher

def base(builtin: Core.Value, +raw: Core.Value, fields: List<&2, Field>) -> Matcher.Matcher:
  match builtin:
    case Core.TextValue{name}:
      Matcher.builtin(name)
    case value:
      Matcher.make(field(raw, "categories"), field(raw, "values"), field_items(fields, "children"))

def from_fields(+raw: Core.Value, +fields: List<&2, Field>) -> Matcher.Matcher:
  modifiers(field(raw, "modifiers"), alternatives(field_items(fields, "alternatives"), base(field(raw, "builtin"), raw, fields)))

def array_items(head: Core.Value, matcher: Matcher.Matcher, tail: List<&2, Matcher.Matcher>) -> List<&2, Matcher.Matcher>:
  match head:
    case Core.NullValue{}:
      tail
    case head:
      matcher <> tail

def combine_array(head: Parsed, tail: Parsed) -> Parsed:
  match head tail:
    case Node{+hr, hm, hi, hf} Node{tr, tm, ti, tf}:
      Node{Core.ArrayCons{hr, tr}, Matcher.make(Core.NullValue{}, Core.NullValue{}, Nil{}), array_items(hr, hm, ti), Nil{}}

def combine_fields(+raw: Core.Value, +fields: List<&2, Field>) -> Parsed:
  Node{raw, from_fields(raw, fields), Nil{}, fields}

def combine_hash(+key: Core.Value, value: Parsed, tail: Parsed) -> Parsed:
  match value tail:
    case Node{vr, vm, vi, vf} Node{tr, tm, ti, tf}:
      combine_fields(Core.HashEntry{key, vr, tr}, Entry{key, vi} <> tf)

def compile(value: Core.Value) -> Parsed:
  match value:
    case Core.ArrayCons{head, tail}:
      a b = compile(head) compile(tail)
      combine_array(a, b)
    case Core.HashEntry{key, value, tail}:
      a b = compile(value) compile(tail)
      combine_hash(key, a, b)
    case value:
      Node{value, Matcher.make(Core.NullValue{}, Core.NullValue{}, Nil{}), Nil{}, Nil{}}

def parsed_matcher(value: Parsed) -> Matcher.Matcher:
  match value:
    case Node{raw, matcher, items, fields}:
      matcher

def construct(input: Core.Value) -> Matcher.Matcher:
  parsed_matcher(compile(input))

def stream(value: Core.Value) -> List<&2, Maybe<&2, Token.Token>>:
  match value:
    case Core.ArrayCons{Core.NullValue{}, tail}:
      None{} <> stream(tail)
    case Core.ArrayCons{head, tail}:
      Some{TokenApi.construct(head)} <> stream(tail)
    case value:
      Nil{}

def token_values(tokens: List<&2, Token.Token>) -> Core.Value:
  match tokens:
    case Nil{}:
      Core.ArrayNil{}
    case token <> tail:
      Core.ArrayCons{TokenApi.describe(token), token_values(tail)}

def decimal_nat(value: Decimal.Decimal) -> Nat:
  match value:
    case Decimal.Exact{digits, scale}:
      Decimal.coefficient(digits)

def match_offset(matcher: Matcher.Matcher, tokens: List<&2, Maybe<&2, Token.Token>>, offset: Core.Value) -> Matcher.MatchResult:
  match offset:
    case Core.NegativeInteger{n}:
      Matcher.match_stream(matcher, tokens, True{}, decimal_nat(n))
    case Core.Number{n}:
      Matcher.match_stream(matcher, tokens, False{}, n)
    case Core.IntegerNumber{n}:
      Matcher.match_stream(matcher, tokens, False{}, decimal_nat(n))
    case offset:
      Matcher.match_stream(matcher, tokens, False{}, 0n)

def result(value: Matcher.MatchResult) -> Core.Value:
  match value:
    case Matcher.Matched{accepted, tokens}:
      Core.ArrayCons{Core.Logical{accepted}, Core.ArrayCons{token_values(tokens), Core.ArrayNil{}}}

def describe(+matcher: Matcher.Matcher) -> Core.Value:
  match matcher:
    case Matcher.Rule{categories, values, children, predicate, inverted, anchored, minimum, repeated}:
      Core.HashEntry{Core.TextValue{"categories"}, categories,
      Core.HashEntry{Core.TextValue{"values"}, values,
      Core.HashEntry{Core.TextValue{"leaf"}, Core.Logical{Matcher.is_leaf(matcher)},
      Core.HashEntry{Core.TextValue{"caret"}, Bool.pick(Core.Value, anchored, Core.Logical{True{}}, Core.NullValue{}),
      Core.HashEntry{Core.TextValue{"minimum"}, Core.Number{minimum},
      Core.HashEntry{Core.TextValue{"maximum"}, Bool.pick(Core.Value, repeated, Core.TextValue{"infinity"}, Core.Number{1n}), Core.HashNil{}}}}}}}

def optional_token(value: Core.Value) -> Maybe<&2, Token.Token>:
  match value:
    case Core.NullValue{}:
      None{}
    case value:
      Some{TokenApi.construct(value)}

def snapshot_ready(operation: String, matcher: Matcher.Matcher, +input: Core.Value) -> String:
  match operation:
    case "accept":
      Core.snapshot(Core.Logical{Matcher.accepts(matcher, optional_token(field(input, "token")))})
    case "match":
      Core.snapshot(result(match_offset(matcher, stream(field(input, "stream")), field(input, "offset"))))
    case operation:
      Core.snapshot(describe(matcher))

def snapshot(operation: String, +input: Core.Value) -> String:
  snapshot_ready(operation, construct(field(input, "matcher")), input)
