import Base
import ./core.bend as Core
import ./dependencies.bend as Dependencies
import ./stored.bend as Stored

@unsafe def bridge(name: String, context: List<&2, Core.Binding>, sensitive: Bool, static: Bool) -> List<&2, String>:
  resolve(name, context, sensitive, static)

@unsafe def resolve(+name: String, +context: List<&2, Core.Binding>, +sensitive: Bool, static: Bool) -> List<&2, String>:
  found(Core.find_binding(context, name, sensitive), name, context, sensitive, static)

@unsafe def found(value: Maybe<&2, Core.Value>, name: String, context: List<&2, Core.Binding>, sensitive: Bool, static: Bool) -> List<&2, String>:
  match value:
    case None{}:
      [Core.normalize(sensitive, name)]
    case Some{Core.StoredExpression{expression, origin}}:
      Dependencies.analyze_using(~bridge, ~Stored.evaluate_in, expression, context, origin, static, Dependencies.CaseUnresolved{})
    case Some{value}:
      Nil{}

def analyze(expression: Core.Expr, context: List<&2, Core.Binding>, sensitive: Bool, static: Bool) -> List<&2, String>:
  Dependencies.analyze_using(~bridge, ~Stored.evaluate_in, expression, context, sensitive, static, Dependencies.CaseUnresolved{})
