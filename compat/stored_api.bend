import Base
import ../src/core.bend as Core
import ../src/parser.bend as Parser
import ../src/calculator.bend as Calculator
import ../src/stored.bend as Stored

def field(input: Core.Value, name: String) -> Core.Value:
  Core.hash_get(input, Core.SymbolValue{name})

def program(parsed: Parser.Parsed, origin: Bool) -> Core.Value:
  match parsed:
    case Parser.Accepted{expression}:
      Core.StoredExpression{expression, origin}
    case Parser.ParseError{message}:
      Core.Failure{message}

def program_source(value: Core.Value, +origin: Bool) -> Core.Value:
  match value:
    case Core.TextValue{source}:
      program(Parser.parse_in(source, origin), origin)
    case value:
      Core.Failure{"Expected a stored formula source"}

def put_programs(programs: Core.Value, state: Calculator.State) -> Calculator.State:
  match programs:
    case Core.HashEntry{key, +descriptor, tail}:
      put_programs(tail, Calculator.set_value(state, key, program_source(field(descriptor, "source"), Core.truthy(field(descriptor, "sensitive")))))
    case programs:
      state

def parsed_snapshot(parsed: Parser.Parsed, context: List<&2, Core.Binding>, sensitive: Bool) -> String:
  match parsed:
    case Parser.Accepted{expression}:
      Core.snapshot(Stored.evaluate_in(expression, context, sensitive))
    case Parser.ParseError{message}:
      Parser.names_snapshot(Parser.NamesError{message})

def snapshot(+input: Core.Value) -> String:
  +origin = Core.truthy(field(input, "root_sensitive"))
  +state = put_programs(field(input, "programs"), Calculator.store_values(Calculator.make(Core.truthy(field(input, "receiver_sensitive")), True{}, False{}), field(input, "data")))
  parsed_snapshot(Parser.parse_in(Core.ruby_render(field(input, "source"), False{}, False{}), origin), Calculator.bindings(Calculator.get_memory(state)), origin)
