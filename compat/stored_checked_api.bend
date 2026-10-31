import Base
import ../src/core.bend as Core
import ../src/parser.bend as Parser
import ../src/calculator.bend as Calculator
import ../src/stored_checked.bend as Checked
import ./stored_api.bend as Api

def render(message: Bool, value: Core.Value) -> String:
  match message:
    case True{}:
      Core.message_snapshot(value)
    case False{}:
      Core.snapshot(value)

def parsed_snapshot(parsed: Parser.Parsed, context: List<&2, Core.Binding>, sensitive: Bool, message: Bool) -> String:
  match parsed:
    case Parser.Accepted{expression}:
      render(message, Checked.evaluate_in(expression, context, sensitive))
    case Parser.ParseError{error}:
      Parser.names_snapshot(Parser.NamesError{error})

def snapshot(+input: Core.Value, message: Bool) -> String:
  +origin = Core.truthy(Api.field(input, "root_sensitive"))
  +state = Api.put_programs(Api.field(input, "programs"), Calculator.store_values(Calculator.make(Core.truthy(Api.field(input, "receiver_sensitive")), True{}, False{}), Api.field(input, "data")))
  parsed_snapshot(Parser.parse_in(Core.ruby_render(Api.field(input, "source"), False{}, False{}), origin), Calculator.bindings(Calculator.get_memory(state)), origin, message)
