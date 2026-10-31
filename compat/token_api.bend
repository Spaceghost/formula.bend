import Base
import ../src/core.bend as Core
import ../src/token.bend as Token

def field(input: Core.Value, name: String) -> Core.Value:
  Core.hash_get(input, Core.SymbolValue{name})

def construct(+input: Core.Value) -> Token.Token:
  Token.with_raw(field(input, "category"), field(input, "value"), field(input, "raw_value"))

def describe(+token: Token.Token) -> Core.Value:
  Core.HashEntry{Core.TextValue{"category"}, Token.get_category(token),
  Core.HashEntry{Core.TextValue{"value"}, Token.get_value(token),
  Core.HashEntry{Core.TextValue{"raw_value"}, Token.get_raw_value(token),
  Core.HashEntry{Core.TextValue{"to_s"}, Token.to_value(token),
  Core.HashEntry{Core.TextValue{"length"}, Core.Number{Token.length(token)},
  Core.HashEntry{Core.TextValue{"empty"}, Core.Logical{Token.is_empty(token)},
  Core.HashEntry{Core.TextValue{"operator"}, Core.Logical{Token.is_operator(token)},
  Core.HashEntry{Core.TextValue{"grouping"}, Core.Logical{Token.is_grouping(token)},
  Core.HashEntry{Core.TextValue{"open"}, Core.Logical{Token.is_open(token)},
  Core.HashEntry{Core.TextValue{"close"}, Core.Logical{Token.is_close(token)}, Core.HashNil{}}}}}}}}}}}

def snapshot(operation: String, +input: Core.Value) -> String:
  match operation:
    case "equal":
      Core.snapshot(Core.Logical{Token.equal(construct(field(input, "left")), construct(field(input, "right")))})
    case "is":
      Core.snapshot(Core.Logical{Token.is_category(construct(field(input, "token")), field(input, "expected"))})
    case operation:
      Core.snapshot(describe(construct(input)))
