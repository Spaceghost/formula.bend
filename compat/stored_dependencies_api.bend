import Base
import ../src/core.bend as Core
import ../src/parser.bend as Parser
import ../src/calculator.bend as Calculator
import ../src/stored_dependencies.bend as Dependencies
import ./stored_api.bend as Api

def names(expression: Core.Expr, +context: List<&2, Core.Binding>, +sensitive: Bool) -> String:
  Core.snapshot(Calculator.name_values(Dependencies.analyze(expression, context, sensitive, Calculator.dependency_static(Core.lookup(context, "__static_dependencies", sensitive)))))

def parsed_snapshot(parsed: Parser.Parsed, context: List<&2, Core.Binding>, sensitive: Bool) -> String:
  match parsed:
    case Parser.Accepted{expression}:
      names(expression, context, sensitive)
    case Parser.ParseError{message}:
      Parser.names_snapshot(Parser.NamesError{message})

def snapshot(+input: Core.Value) -> String:
  +origin = Core.truthy(Api.field(input, "root_sensitive"))
  +state = Api.put_programs(Api.field(input, "programs"), Calculator.store_values(Calculator.make(Core.truthy(Api.field(input, "receiver_sensitive")), True{}, False{}), Api.field(input, "data")))
  parsed_snapshot(Parser.parse_in(Core.ruby_render(Api.field(input, "source"), False{}, False{}), origin), Calculator.bindings(Calculator.get_memory(state)), origin)
