import Base
import ../src/core.bend as Core
import ../src/errors.bend as Errors
import ../src/error_types.bend as Types

# This is a test adapter, not formula syntax. Metadata and constructor arguments
# use the same typed values as the other differential checks.
def construct(factory: String, +input: Core.Value) -> Types.Description<Core.Value>:
  match factory:
    case "parse":
      Errors.parse_error(Errors.field(input, "reason"), Errors.field(input, "meta"))
    case "tokenizer":
      Errors.tokenizer_error(Errors.field(input, "reason"), Errors.field(input, "meta"))
    case "argument":
      Errors.argument_error(Errors.field(input, "reason"), Errors.field(input, "meta"))
    case "unbound":
      Errors.unbound_variable_error(Errors.field(input, "variables"))
    case "math_domain":
      Errors.math_domain_error(Errors.field(input, "function_name"), Errors.field(input, "args"))
    case "node":
      Errors.node_error(Errors.field(input, "expected"), Errors.field(input, "actual"), Errors.field(input, "operand"))
    case "zero_division":
      Errors.zero_division_error()
    case factory:
      Errors.simple("Dentaku::BaseError", Core.HashNil{})

def changed_message(value: Core.Value, +error: Types.Description<Core.Value>) -> Types.Description<Core.Value>:
  match value:
    case Core.NullValue{}:
      Types.with_message(Core.Value, error, Types.class_name(Core.Value, error))
    case value:
      Types.with_message(Core.Value, error, Errors.render(value))

def override_message(present: Bool, value: Core.Value, error: Types.Description<Core.Value>) -> Types.Description<Core.Value>:
  match present:
    case True{}:
      changed_message(value, error)
    case False{}:
      error

def assigned(present: Bool, value: Core.Value, error: Types.Description<Core.Value>) -> Types.Description<Core.Value>:
  match present:
    case True{}:
      Types.with_assigned_to(Core.Value, error, value)
    case False{}:
      error

def describe(+error: Types.Description<Core.Value>) -> Core.Value:
  match error:
    case Types.Details{+class_name, +parents, reason, meta, attributes, message, assigned_to}:
      Core.HashEntry{Core.TextValue{"class"}, Core.TextValue{class_name},
      Core.HashEntry{Core.TextValue{"message"}, Core.TextValue{message},
      Core.HashEntry{Core.TextValue{"dentaku_error"}, Core.Logical{Types.contains(parents, "Dentaku::Error")},
      Core.HashEntry{Core.TextValue{"argument_error"}, Core.Logical{Bool.or(String.eq(class_name, "ArgumentError"), Types.contains(parents, "ArgumentError"))},
      Core.HashEntry{Core.TextValue{"zero_division_error"}, Core.Logical{Types.contains(parents, "ZeroDivisionError")},
      Core.HashEntry{Core.TextValue{"attributes"}, attributes,
      Core.HashEntry{Core.TextValue{"assigned_to"}, assigned_to, Core.HashNil{}}}}}}}}

def snapshot(factory: String, +input: Core.Value) -> String:
  error = construct(factory, input)
  overridden = override_message(Errors.has(input, "override_message"), Errors.field(input, "override_message"), error)
  Core.snapshot(describe(assigned(Errors.has(input, "assigned_to"), Errors.field(input, "assigned_to"), overridden)))
