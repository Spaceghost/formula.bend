import Base
import ../src/core.bend as Core
import ../src/parser.bend as Parser
import ../src/resolver.bend as Resolver
import ../src/string.bend as StringOps
import ./error_factory.bend as ErrorFactory

type Operation is Data:
  Evaluate{}
  Permissive{}
  Identifiers{}
  Dependencies{}
  Class{}
  StaticType{}
  Message{}
  Coerce{}
  CoerceClass{}
  CoerceMessage{}
  ResolveOrder{}
  ResolveCycles{}
  DescribeError{}

type Case is Data:
  Check{id: String, formula: String, operation: Operation, context: List<&2, Core.Binding>, sensitive: Bool, json: Bool}

type Work is Data:
  Leaf{input: Case}
  Fork{left: Work, right: Work}

type Results is Data:
  Result{id: String, snapshot: String}
  Joined{left: Results, right: Results}

def execute_operation(operation: Operation, formula: String, context: List<&2, Core.Binding>, sensitive: Bool) -> String:
  match operation:
    case Evaluate{}:
      Parser.snapshot(formula, context, sensitive)
    case Permissive{}:
      Parser.permissive_snapshot(formula, context, sensitive)
    case Identifiers{}:
      Parser.names_snapshot(Parser.identifiers(formula, sensitive))
    case Dependencies{}:
      Parser.names_snapshot(Parser.dependencies(formula, context, sensitive))
    case Class{}:
      Parser.class_snapshot(formula, context, sensitive)
    case StaticType{}:
      Parser.type_snapshot_in(formula, sensitive)
    case Message{}:
      Parser.message_snapshot(formula, context, sensitive)
    case Coerce{}:
      Core.snapshot(Core.require_numeric(Core.lookup(context, "input", sensitive)))
    case CoerceClass{}:
      Core.class_snapshot(Core.require_numeric(Core.lookup(context, "input", sensitive)))
    case CoerceMessage{}:
      Core.message_snapshot(Core.require_numeric(Core.lookup(context, "input", sensitive)))
    case ResolveOrder{}:
      Resolver.order_snapshot(Core.lookup(context, "input", False{}), sensitive)
    case ResolveCycles{}:
      Resolver.cycles_snapshot(Core.lookup(context, "input", False{}), sensitive)
    case DescribeError{}:
      ErrorFactory.snapshot(formula, Core.lookup(context, "input", False{}))

def frame(json: Bool, snapshot: String) -> String:
  match json:
    case True{}:
      "json:" ++ StringOps.json_quote(snapshot)
    case False{}:
      snapshot

def execute(input: Case) -> Results:
  match input:
    case Check{id, formula, operation, context, sensitive, json}:
      Result{id, frame(json, execute_operation(operation, formula, context, sensitive))}

# Only the input construction and ordered output run on the host. Evaluation,
# dependency analysis, coercion and snapshot generation stay inside the bang.
def evaluate(work: Work) -> Results:
  match work:
    case Leaf{input}:
      execute(input)
    case Fork{left, right}:
      a b = evaluate(left) evaluate(right)
      Joined{a, b}

def emit(results: Results) -> IO(Unit):
  match results:
    case Result{id, snapshot}:
      IO.print(id ++ "\t" ++ snapshot)
    case Joined{left, right}:
      do IO<Unit>:
        emit(left)
        emit(right)
