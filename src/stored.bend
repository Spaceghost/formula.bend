import Base
import ./core.bend as Core

# A filled bridge lets the evaluator template call the recursive resolver.
# Recursive user programs need not terminate, so this runner is deliberately
# outside the total evaluator's mathematical proof imports.
@unsafe def bridge(context: List<&2, Core.Binding>, name: String, sensitive: Bool, subjects: List<&2, Core.Value>) -> Core.Value:
  resolve(context, name, sensitive, subjects)

@unsafe def resolve(+context: List<&2, Core.Binding>, name: String, sensitive: Bool, subjects: List<&2, Core.Value>) -> Core.Value:
  expand(Core.lookup(context, name, sensitive), context)

@unsafe def expand(value: Core.Value, context: List<&2, Core.Binding>) -> Core.Value:
  match value:
    case Core.StoredExpression{expression, origin}:
      Core.evaluate_using(~bridge, Core.prepare_expression(expression), Core.EmptyArgumentValues{}, context, origin, Nil{}, Core.EvaluateOne{})
    case value:
      value

def evaluate_in(expression: Core.Expr, context: List<&2, Core.Binding>, sensitive: Bool) -> Core.Value:
  Core.evaluate_using(~bridge, Core.prepare_expression(expression), Core.EmptyArgumentValues{}, context, sensitive, Nil{}, Core.EvaluateOne{})
