import Base
import ./core.bend as Core
import ./dependencies.bend as Names
import ./stored_dependencies.bend as Dependencies
import ./stored.bend as Stored

def static_mode(value: Core.Value) -> Bool:
  match value:
    case Core.Logical{True{}}:
      True{}
    case value:
      False{}

def preflight(missing: Names.DependencyResult, expression: Core.Expr, context: List<&2, Core.Binding>, sensitive: Bool) -> Core.Value:
  match missing:
    case Names.AnalysisNativeError{class_name, message}:
      Core.Raised{class_name, message}
    case Names.AnalysisNames{Nil{}}:
      Stored.evaluate_in(expression, context, sensitive)
    case Names.AnalysisNames{names}:
      Core.Failure{"no value provided for variables: " ++ String.join(Names.unique(names, Nil{}), ", ")}

def evaluate_prepared(+expression: Core.Expr, +context: List<&2, Core.Binding>, +sensitive: Bool) -> Core.Value:
  preflight(Dependencies.analyze(expression, context, sensitive, static_mode(Core.lookup(context, "__static_dependencies", sensitive))), expression, context, sensitive)

def evaluate_in(expression: Core.Expr, context: List<&2, Core.Binding>, sensitive: Bool) -> Core.Value:
  evaluate_prepared(expression, context, sensitive)
