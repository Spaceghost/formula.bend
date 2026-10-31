import Base
import ./core.bend as Core
import ./error_types.bend as Types

type ReasonCode is Data:
  NodeInvalid{}
  TooFewOperands{}
  TooManyOperands{}
  UndefinedFunction{}
  UnprocessedToken{}
  UnknownCaseToken{}
  UnbalancedBracket{}
  UnbalancedParenthesis{}
  UnknownGroupingToken{}
  NotImplementedTokenCategory{}
  InvalidStatement{}
  ParseError{}
  TooManyClosingParentheses{}
  TooManyOpeningParentheses{}
  UnexpectedZeroWidthMatch{}
  IncompatibleType{}
  InvalidOperator{}
  InvalidValue{}
  TooFewArguments{}
  WrongNumberOfArguments{}
  UnrecognizedReason{}

type NamedReason is Data:
  ReasonEntry{name: String, code: ReasonCode}

def find_reason(entries: List<&2, NamedReason>, +name: String) -> ReasonCode:
  match entries:
    case Nil{}:
      UnrecognizedReason{}
    case ReasonEntry{key, code} <> rest:
      Bool.pick(ReasonCode, String.eq(key, name), code, find_reason(rest, name))

# String equality is shared instead of specializing a nested character-pattern
# tree into every factory. Formatting still accepts only its own reason group.
def reason_code(name: String) -> ReasonCode:
  find_reason([
    ReasonEntry{"node_invalid", NodeInvalid{}},
    ReasonEntry{"too_few_operands", TooFewOperands{}},
    ReasonEntry{"too_many_operands", TooManyOperands{}},
    ReasonEntry{"undefined_function", UndefinedFunction{}},
    ReasonEntry{"unprocessed_token", UnprocessedToken{}},
    ReasonEntry{"unknown_case_token", UnknownCaseToken{}},
    ReasonEntry{"unbalanced_bracket", UnbalancedBracket{}},
    ReasonEntry{"unbalanced_parenthesis", UnbalancedParenthesis{}},
    ReasonEntry{"unknown_grouping_token", UnknownGroupingToken{}},
    ReasonEntry{"not_implemented_token_category", NotImplementedTokenCategory{}},
    ReasonEntry{"invalid_statement", InvalidStatement{}},
    ReasonEntry{"parse_error", ParseError{}},
    ReasonEntry{"too_many_closing_parentheses", TooManyClosingParentheses{}},
    ReasonEntry{"too_many_opening_parentheses", TooManyOpeningParentheses{}},
    ReasonEntry{"unexpected_zero_width_match", UnexpectedZeroWidthMatch{}},
    ReasonEntry{"incompatible_type", IncompatibleType{}},
    ReasonEntry{"invalid_operator", InvalidOperator{}},
    ReasonEntry{"invalid_value", InvalidValue{}},
    ReasonEntry{"too_few_arguments", TooFewArguments{}},
    ReasonEntry{"wrong_number_of_arguments", WrongNumberOfArguments{}}
  ], name)

# Exception factories are separate from evaluator propagation. Metadata retains
# the original value and key types; formatting never replaces the payload.
def field(meta: Core.Value, name: String) -> Core.Value:
  Core.hash_get(meta, Core.SymbolValue{name})

def found(value: Maybe<&2, Core.Value>) -> Bool:
  match value:
    case Some{value}:
      True{}
    case None{}:
      False{}

def has(meta: Core.Value, name: String) -> Bool:
  found(Core.hash_find(meta, Core.SymbolValue{name}))

def render(value: Core.Value) -> String:
  Core.ruby_render(value, False{}, False{})

def shown(meta: Core.Value, name: String) -> String:
  render(field(meta, name))

def expected_count(value: Core.Value) -> String:
  match value:
    case Core.RangeValue{first, Core.NullValue{}, excluded}:
      "at least " ++ render(first)
    case value:
      render(value)

def parents(base: String, dentaku: Bool) -> List<&2, String>:
  match dentaku:
    case True{}:
      "Dentaku::Error" <> base <> ["StandardError", "Exception", "Object", "Kernel", "BasicObject"]
    case False{}:
      base <> ["StandardError", "Exception", "Object", "Kernel", "BasicObject"]

def build(class_name: String, ancestors: List<&2, String>, reason: Maybe<&2, Core.Value>, meta: Core.Value, attributes: Core.Value, message: String) -> Types.Description<Core.Value>:
  Types.Details{class_name, ancestors, reason, meta, attributes, message, Core.NullValue{}}

def simple(+class_name: String, attributes: Core.Value) -> Types.Description<Core.Value>:
  build(class_name, parents("Dentaku::BaseError", True{}), None{}, Core.HashNil{}, attributes, class_name)

def reason_attributes(reason: Core.Value, meta: Core.Value) -> Core.Value:
  Core.HashEntry{Core.SymbolValue{"reason"}, reason, Core.HashEntry{Core.SymbolValue{"meta"}, meta, Core.HashNil{}}}

def reasoned(class_name: String, base: String, +reason: Core.Value, +meta: Core.Value, message: String) -> Types.Description<Core.Value>:
  build(class_name, parents(base, True{}), Some{reason}, meta, reason_attributes(reason, meta), message)

def unhandled(reason: Core.Value) -> Types.Description<Core.Value>:
  build("ArgumentError", ["StandardError", "Exception", "Object", "Kernel", "BasicObject"], None{}, Core.HashNil{}, Core.HashNil{}, "Unhandled " ++ render(reason))

def hash_array(value: Core.Value) -> Core.Value:
  match value:
    case Core.HashEntry{key, item, tail}:
      Core.ArrayCons{Core.ArrayCons{key, Core.ArrayCons{item, Core.ArrayNil{}}}, hash_array(tail)}
    case value:
      Core.ArrayNil{}

def as_array(value: Core.Value) -> Core.Value:
  match value:
    case Core.NullValue{}:
      Core.ArrayNil{}
    case Core.ArrayNil{}:
      Core.ArrayNil{}
    case Core.ArrayCons{head, tail}:
      Core.ArrayCons{head, tail}
    case Core.HashNil{}:
      Core.ArrayNil{}
    case Core.HashEntry{key, item, tail}:
      hash_array(Core.HashEntry{key, item, tail})
    case value:
      Core.ArrayCons{value, Core.ArrayNil{}}

def join_separator(values: Core.Value, separator: String) -> String:
  match values:
    case Core.ArrayCons{head, tail}:
      separator
    case values:
      ""

def joined(value: Core.Value, +separator: String) -> String:
  match value:
    case Core.ArrayNil{}:
      ""
    case Core.ArrayCons{head, +tail}:
      joined(head, separator) ++ join_separator(tail, separator) ++ joined(tail, separator)
    case value:
      render(value)

def expected_name(value: Core.Value) -> String:
  match value:
    case Core.SymbolValue{+name}:
      Bool.pick(String, String.eq(name, "incompatible"), "compatible", name)
    case Core.ArrayCons{head, tail}:
      joined(Core.ArrayCons{head, tail}, ", ")
    case Core.ArrayNil{}:
      ""
    case value:
      render(value)

def expected_names(values: Core.Value, separator: String) -> String:
  match values:
    case Core.ArrayCons{head, tail}:
      separator ++ expected_name(head) ++ expected_names(tail, ", ")
    case values:
      ""

def parse_message_code(reason: ReasonCode, +meta: Core.Value) -> Maybe<&2, String>:
  match reason:
    case NodeInvalid{}:
      Some{Bool.pick(String, has(meta, "operation"), shown(meta, "operation") ++ " requires " ++ expected_names(as_array(field(meta, "expected")), "") ++ " operands, but got " ++ shown(meta, "actual"), "Node is invalid")}
    case TooFewOperands{}:
      Some{shown(meta, "operation") ++ " has too few operands (given " ++ shown(meta, "actual") ++ ", expected " ++ shown(meta, "expected") ++ ")"}
    case TooManyOperands{}:
      Some{shown(meta, "operation") ++ " has too many operands (given " ++ shown(meta, "actual") ++ ", expected " ++ shown(meta, "expected") ++ ")"}
    case UndefinedFunction{}:
      Some{"Undefined function " ++ shown(meta, "function_name")}
    case UnprocessedToken{}:
      Some{"Unprocessed token " ++ shown(meta, "token_name")}
    case UnknownCaseToken{}:
      Some{"Unknown case token " ++ shown(meta, "token_name")}
    case UnbalancedBracket{}:
      Some{"Unbalanced bracket"}
    case UnbalancedParenthesis{}:
      Some{"Unbalanced parenthesis"}
    case UnknownGroupingToken{}:
      Some{"Unknown grouping token " ++ shown(meta, "token_name")}
    case NotImplementedTokenCategory{}:
      Some{"Not implemented for tokens of category " ++ shown(meta, "token_category")}
    case InvalidStatement{}:
      Some{"Invalid statement"}
    case reason:
      None{}

def tokenizer_message_code(reason: ReasonCode, +meta: Core.Value) -> Maybe<&2, String>:
  match reason:
    case ParseError{}:
      Some{"parse error at: '" ++ shown(meta, "at") ++ "'"}
    case TooManyOpeningParentheses{}:
      Some{"too many opening parentheses"}
    case TooManyClosingParentheses{}:
      Some{"too many closing parentheses"}
    case UnexpectedZeroWidthMatch{}:
      Some{"unexpected zero-width match (:" ++ shown(meta, "token_category") ++ ") at '" ++ shown(meta, "at") ++ "'"}
    case reason:
      None{}

def argument_message_code(reason: ReasonCode, +meta: Core.Value) -> Maybe<&2, String>:
  match reason:
    case IncompatibleType{}:
      +actual = Core.ruby_type_name(field(meta, "actual"))
      Some{Bool.pick(String, has(meta, "function_name"), shown(meta, "function_name") ++ "() requires " ++ shown(meta, "expected") ++ " arguments, but got " ++ actual, actual ++ " is not compatible with " ++ shown(meta, "expected"))}
    case InvalidOperator{}:
      Some{shown(meta, "operation") ++ " requires operands that respond to " ++ shown(meta, "operator")}
    case InvalidValue{}:
      Some{Bool.pick(String, has(meta, "expected"), "'" ++ shown(meta, "actual") ++ "' is not a valid " ++ shown(meta, "expected"), Bool.pick(String, has(meta, "actual"), "'" ++ shown(meta, "actual") ++ "' is not a valid value", "Invalid value"))}
    case TooFewArguments{}:
      Some{shown(meta, "function_name") ++ "() has too few arguments (given " ++ shown(meta, "actual") ++ ", expected " ++ expected_count(field(meta, "expected")) ++ ")"}
    case WrongNumberOfArguments{}:
      Some{shown(meta, "function_name") ++ "() has the wrong number of arguments (given " ++ shown(meta, "actual") ++ ", expected " ++ expected_count(field(meta, "expected")) ++ ")"}
    case reason:
      None{}

def parse_message(reason: String, meta: Core.Value) -> Maybe<&2, String>:
  parse_message_code(reason_code(reason), meta)

def tokenizer_message(reason: String, meta: Core.Value) -> Maybe<&2, String>:
  tokenizer_message_code(reason_code(reason), meta)

def argument_message(reason: String, meta: Core.Value) -> Maybe<&2, String>:
  argument_message_code(reason_code(reason), meta)

def completed(message: Maybe<&2, String>, class_name: String, base: String, reason: Core.Value, meta: Core.Value) -> Types.Description<Core.Value>:
  match message:
    case Some{text}:
      reasoned(class_name, base, reason, meta, text)
    case None{}:
      unhandled(reason)

def parse_error(+reason: Core.Value, +meta: Core.Value) -> Types.Description<Core.Value>:
  match reason:
    case Core.SymbolValue{name}:
      completed(parse_message(name, meta), "Dentaku::ParseError", "Dentaku::BaseError", Core.SymbolValue{name}, meta)
    case reason:
      unhandled(reason)

def tokenizer_error(+reason: Core.Value, +meta: Core.Value) -> Types.Description<Core.Value>:
  match reason:
    case Core.SymbolValue{name}:
      completed(tokenizer_message(name, meta), "Dentaku::TokenizerError", "Dentaku::BaseError", Core.SymbolValue{name}, meta)
    case reason:
      unhandled(reason)

def argument_error(+reason: Core.Value, +meta: Core.Value) -> Types.Description<Core.Value>:
  match reason:
    case Core.SymbolValue{name}:
      completed(argument_message(name, meta), "Dentaku::ArgumentError", "ArgumentError", Core.SymbolValue{name}, meta)
    case reason:
      unhandled(reason)

def unbound_variable_error(variables: Core.Value) -> Types.Description<Core.Value>:
  simple("Dentaku::UnboundVariableError", Core.HashEntry{Core.SymbolValue{"unbound_variables"}, variables, Core.HashNil{}})

def math_domain_error(name: Core.Value, arguments: Core.Value) -> Types.Description<Core.Value>:
  simple("Dentaku::MathDomainError", Core.HashEntry{Core.SymbolValue{"function_name"}, name, Core.HashEntry{Core.SymbolValue{"args"}, arguments, Core.HashNil{}}})

def node_error(expected: Core.Value, actual: Core.Value, operand: Core.Value) -> Types.Description<Core.Value>:
  simple("Dentaku::NodeError", Core.HashEntry{Core.SymbolValue{"expected"}, as_array(expected), Core.HashEntry{Core.SymbolValue{"actual"}, actual, Core.HashEntry{Core.SymbolValue{"operand"}, operand, Core.HashNil{}}}})

def zero_division_error() -> Types.Description<Core.Value>:
  build("Dentaku::ZeroDivisionError", parents("ZeroDivisionError", True{}), None{}, Core.HashNil{}, Core.HashNil{}, "Dentaku::ZeroDivisionError")
