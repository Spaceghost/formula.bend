import Base
import ./core.bend as Core

# A lexical token retains its category, semantic value and original spelling.
# This public descriptor is distinct from the parser's internal token variants.
type Token is Data:
  Lexeme{category: Core.Value, value: Core.Value, raw_value: Core.Value}

def make(category: Core.Value, value: Core.Value) -> Token:
  Lexeme{category, value, Core.NullValue{}}

def with_raw(category: Core.Value, value: Core.Value, raw_value: Core.Value) -> Token:
  Lexeme{category, value, raw_value}

def get_category(token: Token) -> Core.Value:
  match token:
    case Lexeme{category, value, raw_value}:
      category

def get_value(token: Token) -> Core.Value:
  match token:
    case Lexeme{category, value, raw_value}:
      value

def get_raw_value(token: Token) -> Core.Value:
  match token:
    case Lexeme{category, value, raw_value}:
      raw_value

# Ruby Token#to_s can return a non-String: it is raw_value || value.
def to_value(token: Token) -> Core.Value:
  match token:
    case Lexeme{category, +value, +raw_value}:
      Bool.pick(Core.Value, Core.truthy(raw_value), raw_value, value)

# The length belongs to raw_value.to_s, even if to_value selected value.
def length(token: Token) -> Nat:
  String.length(Core.ruby_render(get_raw_value(token), False{}, False{}))

def is_empty(token: Token) -> Bool:
  Nat.is_eq(length(token), 0n)

def is_category(token: Token, expected: Core.Value) -> Bool:
  Core.value_equal(get_category(token), expected, False{})

def is_operator(token: Token) -> Bool:
  is_category(token, Core.SymbolValue{"operator"})

def is_grouping(token: Token) -> Bool:
  is_category(token, Core.SymbolValue{"grouping"})

def is_open(+token: Token) -> Bool:
  Bool.and(is_grouping(token), Core.value_equal(get_value(token), Core.SymbolValue{"open"}, False{}))

def is_close(+token: Token) -> Bool:
  Bool.and(is_grouping(token), Core.value_equal(get_value(token), Core.SymbolValue{"close"}, False{}))

# Nil is a wildcard in either token's category or value. This is deliberately
# distinct from ordinary value equality and need not be transitive.
def wildcard_equal(a: Core.Value, b: Core.Value) -> Bool:
  match a:
    case Core.NullValue{}:
      True{}
    case a:
      match b:
        case Core.NullValue{}:
          True{}
        case b:
          Core.value_equal(a, b, False{})

def equal(a: Token, b: Token) -> Bool:
  match a b:
    case Lexeme{ac, av, ar} Lexeme{bc, bv, br}:
      categories values = wildcard_equal(ac, bc) wildcard_equal(av, bv)
      Bool.and(categories, values)
