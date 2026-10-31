import Base
import ./core.bend as Core

def present_pick(found: Bool, next: Unit -> Bool) -> Bool:
  match found:
    case True{}:
      True{}
    case False{}:
      next(Unit{})

def present(context: List<&2, Core.Binding>, +name: String, +sensitive: Bool) -> Bool:
  match context:
    case Nil{}:
      False{}
    case Core.Bound{key, value} <> rest:
      present_pick(String.eq(Core.normalize(sensitive, key), Core.normalize(sensitive, name)), u => present(rest, name, sensitive))
    case Core.ScopedBound{key, value} <> rest:
      present_pick(String.eq(key, Core.normalize(sensitive, name)), u => present(rest, name, sensitive))
    case Core.SymbolBound{key, value} <> rest:
      present_pick(String.eq(Core.normalize(sensitive, key), Core.normalize(sensitive, name)), u => present(rest, name, sensitive))

def contains(names: List<&2, String>, +name: String) -> Bool:
  match names:
    case Nil{}:
      False{}
    case head <> rest:
      present_pick(String.eq(head, name), u => contains(rest, name))

def unique_pick(duplicate: Bool, head: String, next: Unit -> List<&2, String>) -> List<&2, String>:
  match duplicate:
    case True{}:
      next(Unit{})
    case False{}:
      head <> next(Unit{})

def unique(names: List<&2, String>, +seen: List<&2, String>) -> List<&2, String>:
  match names:
    case Nil{}:
      Nil{}
    case +head <> rest:
      unique_pick(contains(seen, head), head, u => unique(rest, head <> seen))

def union(a: List<&2, String>, b: List<&2, String>) -> List<&2, String>:
  unique(List.append(&2, String, a, b), Nil{})

def variable(+name: String, context: List<&2, Core.Binding>, +sensitive: Bool, static: Bool) -> List<&2, String>:
  Bool.pick(List<&2, String>, Bool.not(present(context, name, sensitive)), [Core.normalize(sensitive, name)], Nil{})

# Native guard failures are distinct from unresolved variable names. Dentaku
# failures still trigger fallback analysis, as in the pinned Ruby implementation.
type DependencyResult is Data:
  AnalysisNames{names: List<&2, String>}
  AnalysisNativeError{class_name: String, message: String}

def static_mode(value: Core.Value) -> Bool:
  match value:
    case Core.Logical{True{}}:
      True{}
    case value:
      False{}

def append_result(a: DependencyResult, b: DependencyResult) -> DependencyResult:
  match a:
    case AnalysisNativeError{class_name, message}:
      AnalysisNativeError{class_name, message}
    case AnalysisNames{a}:
      match b:
        case AnalysisNativeError{class_name, message}:
          AnalysisNativeError{class_name, message}
        case AnalysisNames{b}:
          AnalysisNames{List.append(&2, String, a, b)}

def unique_result(result: DependencyResult) -> DependencyResult:
  match result:
    case AnalysisNames{names}:
      AnalysisNames{unique(names, Nil{})}
    case result:
      result

def union_result(a: DependencyResult, b: DependencyResult) -> DependencyResult:
  unique_result(append_result(a, b))

def branch(chosen: Bool, yes: Unit -> DependencyResult, no: Unit -> DependencyResult) -> DependencyResult:
  match chosen:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def conditional(value: Core.Value, yes: Unit -> DependencyResult, no: Unit -> DependencyResult, fallback: Unit -> DependencyResult) -> DependencyResult:
  match value:
    case Core.Raised{class_name, message}:
      AnalysisNativeError{class_name, message}
    case Core.Failure{e}:
      fallback(Unit{})
    case value:
      branch(Core.truthy(value), yes, no)

def logical_probe(value: Core.Value, is_and: Bool, names: List<&2, String>, next: Unit -> DependencyResult) -> DependencyResult:
  match value:
    case Core.Raised{class_name, message}:
      AnalysisNativeError{class_name, message}
    case Core.Failure{e}:
      AnalysisNames{names}
    case value:
      branch(Core.decisive(is_and, value), u => AnalysisNames{Nil{}}, next)

def logical_right_using(~evaluate: Core.Expr -> List<&2, Core.Binding> -> Bool -> Core.Value, +a: List<&2, String>, b: List<&2, String>, right: Core.Expr, is_and: Bool, context: List<&2, Core.Binding>, sensitive: Bool) -> DependencyResult:
  match b:
    case Nil{}:
      logical_probe(evaluate(right, context, sensitive), is_and, unique(a, Nil{}), u => AnalysisNames{unique(a, Nil{})})
    case b:
      AnalysisNames{union(a, b)}

def logical_using(~evaluate: Core.Expr -> List<&2, Core.Binding> -> Bool -> Core.Value, a: DependencyResult, b: DependencyResult, left: Core.Expr, +right: Core.Expr, +is_and: Bool, +context: List<&2, Core.Binding>, +sensitive: Bool) -> DependencyResult:
  match a b:
    case AnalysisNativeError{class_name, message} b:
      AnalysisNativeError{class_name, message}
    case a AnalysisNativeError{class_name, message}:
      AnalysisNativeError{class_name, message}
    case AnalysisNames{Nil{}} AnalysisNames{+b}:
      logical_probe(evaluate(left, context, sensitive), is_and, unique(b, Nil{}), u => logical_right_using(~evaluate, Nil{}, b, right, is_and, context, sensitive))
    case AnalysisNames{a} AnalysisNames{b}:
      logical_right_using(~evaluate, a, b, right, is_and, context, sensitive)

def logical_mode_using(~evaluate: Core.Expr -> List<&2, Core.Binding> -> Bool -> Core.Value, static: Bool, a: DependencyResult, b: DependencyResult, left: Core.Expr, right: Core.Expr, is_and: Bool, context: List<&2, Core.Binding>, sensitive: Bool) -> DependencyResult:
  match static:
    case True{}:
      union_result(a, b)
    case False{}:
      logical_using(~evaluate, a, b, left, right, is_and, context, sensitive)

type CaseChoice is Data:
  CaseUnresolved{}
  CaseSelected{index: Nat}
  CaseNativeError{class_name: String, message: String}

def next_case_choice(choice: CaseChoice) -> CaseChoice:
  match choice:
    case CaseSelected{n}:
      CaseSelected{1n+n}
    case choice:
      choice

def case_key_decision(matches: Bool, next: Unit -> CaseChoice) -> CaseChoice:
  match matches:
    case True{}:
      CaseSelected{0n}
    case False{}:
      next_case_choice(next(Unit{}))

def case_key(key: Core.Value, subject: Core.Value, next: Unit -> CaseChoice) -> CaseChoice:
  match key:
    case Core.Raised{class_name, message}:
      CaseNativeError{class_name, message}
    case Core.Failure{message}:
      CaseUnresolved{}
    case key:
      case_key_decision(Core.value_equal(key, subject, False{}), next)

def select_case_using(~evaluate: Core.Expr -> List<&2, Core.Binding> -> Bool -> Core.Value, clauses: Core.Expr, +subject: Core.Value, +context: List<&2, Core.Binding>, +sensitive: Bool) -> CaseChoice:
  match clauses:
    case Core.WhenExpression{key, value, rest}:
      case_key(evaluate(key, context, sensitive), subject, u => select_case_using(~evaluate, rest, subject, context, sensitive))
    case Core.ElseExpression{value}:
      CaseSelected{0n}
    case Core.NoCaseMatch{}:
      CaseSelected{0n}
    case clauses:
      CaseUnresolved{}

def select_case_subject_using(~evaluate: Core.Expr -> List<&2, Core.Binding> -> Bool -> Core.Value, subject: Core.Value, clauses: Core.Expr, context: List<&2, Core.Binding>, sensitive: Bool) -> CaseChoice:
  match subject:
    case Core.Raised{class_name, message}:
      CaseNativeError{class_name, message}
    case Core.Failure{message}:
      CaseUnresolved{}
    case subject:
      select_case_using(~evaluate, clauses, subject, context, sensitive)

def case_choice_using(~evaluate: Core.Expr -> List<&2, Core.Binding> -> Bool -> Core.Value, static: Bool, subject: Core.Expr, clauses: Core.Expr, +context: List<&2, Core.Binding>, +sensitive: Bool) -> CaseChoice:
  match static:
    case True{}:
      CaseUnresolved{}
    case False{}:
      select_case_subject_using(~evaluate, evaluate(subject, context, sensitive), clauses, context, sensitive)

def case_dependencies(choice: CaseChoice, subject: Unit -> DependencyResult, clauses: Unit -> DependencyResult) -> DependencyResult:
  match choice:
    case CaseNativeError{class_name, message}:
      AnalysisNativeError{class_name, message}
    case CaseUnresolved{}:
      append_result(subject(Unit{}), clauses(Unit{}))
    case CaseSelected{n}:
      clauses(Unit{})

def when_dependencies(choice: CaseChoice, all: Unit -> DependencyResult, yes: Unit -> DependencyResult, no: Nat -> DependencyResult) -> DependencyResult:
  match choice:
    case CaseNativeError{class_name, message}:
      AnalysisNativeError{class_name, message}
    case CaseUnresolved{}:
      all(Unit{})
    case CaseSelected{0n}:
      yes(Unit{})
    case CaseSelected{1n+p}:
      no(p)

def binder_dependency(binders: List<&2, String>, +name: String) -> Bool:
  match binders:
    case Nil{}:
      False{}
    case +binder <> rest:
      Bool.or(Bool.or(String.eq(name, binder), String.starts_with(name, binder ++ ".")), binder_dependency(rest, name))

def remove_binder_dependencies(names: List<&2, String>, +binders: List<&2, String>) -> List<&2, String>:
  match names:
    case Nil{}:
      Nil{}
    case +head <> rest:
      unique_pick(binder_dependency(binders, head), head, u => remove_binder_dependencies(rest, binders))

def remove_binder_result(result: DependencyResult, binders: List<&2, String>) -> DependencyResult:
  match result:
    case AnalysisNames{names}:
      AnalysisNames{remove_binder_dependencies(names, binders)}
    case result:
      result

def resolve_variable(name: String, context: List<&2, Core.Binding>, sensitive: Bool, static: Bool) -> DependencyResult:
  AnalysisNames{variable(name, context, sensitive, static)}

def analyze_using(~resolve: String -> List<&2, Core.Binding> -> Bool -> Bool -> DependencyResult, ~evaluate: Core.Expr -> List<&2, Core.Binding> -> Bool -> Core.Value, expr: Core.Expr, +context: List<&2, Core.Binding>, +sensitive: Bool, +static: Bool, choice: CaseChoice) -> DependencyResult:
  match expr:
    case Core.MidExpression{value, offset, length}:
      append_result(analyze_using(~resolve, ~evaluate, value, context, sensitive, static, CaseUnresolved{}), append_result(analyze_using(~resolve, ~evaluate, offset, context, sensitive, static, CaseUnresolved{}), analyze_using(~resolve, ~evaluate, length, context, sensitive, static, CaseUnresolved{})))
    case Core.ContainsExpression{needle, haystack}:
      append_result(analyze_using(~resolve, ~evaluate, needle, context, sensitive, static, CaseUnresolved{}), analyze_using(~resolve, ~evaluate, haystack, context, sensitive, static, CaseUnresolved{}))
    case Core.CountOneExpression{value}:
      analyze_using(~resolve, ~evaluate, value, context, sensitive, static, CaseUnresolved{})
    case Core.CountManyExpression{arguments, count}:
      analyze_using(~resolve, ~evaluate, arguments, context, sensitive, static, CaseUnresolved{})
    case Core.EnumerationExpression{kind, collection, binder, body}:
      append_result(analyze_using(~resolve, ~evaluate, collection, context, sensitive, static, CaseUnresolved{}), remove_binder_result(analyze_using(~resolve, ~evaluate, body, context, sensitive, static, CaseUnresolved{}), [Core.normalize(sensitive, binder)]))
    case Core.ReductionExpression{collection, memo_binder, item_binder, body, initial}:
      append_result(analyze_using(~resolve, ~evaluate, collection, context, sensitive, static, CaseUnresolved{}), append_result(remove_binder_result(analyze_using(~resolve, ~evaluate, body, context, sensitive, static, CaseUnresolved{}), [Core.normalize(sensitive, memo_binder), Core.normalize(sensitive, item_binder)]), analyze_using(~resolve, ~evaluate, initial, context, sensitive, static, CaseUnresolved{})))
    case Core.CaseExpression{+subject, +clauses}:
      +selected = case_choice_using(~evaluate, static, subject, clauses, context, sensitive)
      case_dependencies(selected, u => analyze_using(~resolve, ~evaluate, subject, context, sensitive, static, CaseUnresolved{}), u => analyze_using(~resolve, ~evaluate, clauses, context, sensitive, static, selected))
    case Core.WhenExpression{key, +value, +rest}:
      when_dependencies(choice, u => append_result(analyze_using(~resolve, ~evaluate, key, context, sensitive, static, CaseUnresolved{}), append_result(analyze_using(~resolve, ~evaluate, value, context, sensitive, static, CaseUnresolved{}), analyze_using(~resolve, ~evaluate, rest, context, sensitive, static, CaseUnresolved{}))), u => analyze_using(~resolve, ~evaluate, value, context, sensitive, static, CaseUnresolved{}), p => analyze_using(~resolve, ~evaluate, rest, context, sensitive, static, CaseSelected{p}))
    case Core.ElseExpression{value}:
      analyze_using(~resolve, ~evaluate, value, context, sensitive, static, CaseUnresolved{})
    case Core.NoCaseMatch{}:
      AnalysisNames{Nil{}}
    case Core.ArrayLiteral{a}:
      analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{})
    case Core.Access{a, b}:
      x y = analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{}) analyze_using(~resolve, ~evaluate, b, context, sensitive, static, CaseUnresolved{})
      append_result(x, y)
    case Core.EmptyArguments{}:
      AnalysisNames{Nil{}}
    case Core.Argument{a, validation}:
      analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{})
    case Core.Arguments{a, b}:
      x y = analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{}) analyze_using(~resolve, ~evaluate, b, context, sensitive, static, CaseUnresolved{})
      append_result(x, y)
    case Core.FunctionCall{kind, arguments}:
      analyze_using(~resolve, ~evaluate, arguments, context, sensitive, static, CaseUnresolved{})
    case Core.Literal{v}:
      AnalysisNames{Nil{}}
    case Core.Variable{name}:
      resolve(name, context, sensitive, static)
    case Core.Add{a, b}:
      x y = analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{}) analyze_using(~resolve, ~evaluate, b, context, sensitive, static, CaseUnresolved{})
      union_result(x, y)
    case Core.Subtract{a, b}:
      x y = analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{}) analyze_using(~resolve, ~evaluate, b, context, sensitive, static, CaseUnresolved{})
      union_result(x, y)
    case Core.Multiply{a, b}:
      x y = analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{}) analyze_using(~resolve, ~evaluate, b, context, sensitive, static, CaseUnresolved{})
      union_result(x, y)
    case Core.Divide{a, b}:
      x y = analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{}) analyze_using(~resolve, ~evaluate, b, context, sensitive, static, CaseUnresolved{})
      union_result(x, y)
    case Core.Modulo{a, b}:
      x y = analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{}) analyze_using(~resolve, ~evaluate, b, context, sensitive, static, CaseUnresolved{})
      union_result(x, y)
    case Core.Bitwise{kind, a, b}:
      x y = analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{}) analyze_using(~resolve, ~evaluate, b, context, sensitive, static, CaseUnresolved{})
      union_result(x, y)
    case Core.Compare{op, a, b}:
      x y = analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{}) analyze_using(~resolve, ~evaluate, b, context, sensitive, static, CaseUnresolved{})
      union_result(x, y)
    case Core.Xor{a, b}:
      x y = analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{}) analyze_using(~resolve, ~evaluate, b, context, sensitive, static, CaseUnresolved{})
      union_result(x, y)
    case Core.Round{a, places, mode}:
      x y = analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{}) analyze_using(~resolve, ~evaluate, places, context, sensitive, static, CaseUnresolved{})
      append_result(x, y)
    case Core.Negate{a}:
      analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{})
    case Core.Percentage{a}:
      analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{})
    case Core.Not{a}:
      analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{})
    case Core.PrefixNot{a}:
      analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{})
    case Core.CoerceNumber{a}:
      analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{})
    case Core.And{+a, +b}:
      x y = analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{}) analyze_using(~resolve, ~evaluate, b, context, sensitive, static, CaseUnresolved{})
      logical_mode_using(~evaluate, static, x, y, a, b, True{}, context, sensitive)
    case Core.Or{+a, +b}:
      x y = analyze_using(~resolve, ~evaluate, a, context, sensitive, static, CaseUnresolved{}) analyze_using(~resolve, ~evaluate, b, context, sensitive, static, CaseUnresolved{})
      logical_mode_using(~evaluate, static, x, y, a, b, False{}, context, sensitive)
    case Core.If{+c, +a, +b}:
      branch(static, u => union_result(analyze_using(~resolve, ~evaluate, c, context, sensitive, True{}, CaseUnresolved{}), union_result(analyze_using(~resolve, ~evaluate, a, context, sensitive, True{}, CaseUnresolved{}), analyze_using(~resolve, ~evaluate, b, context, sensitive, True{}, CaseUnresolved{}))), u => conditional(evaluate(c, context, sensitive), u => analyze_using(~resolve, ~evaluate, a, context, sensitive, False{}, CaseUnresolved{}), u => analyze_using(~resolve, ~evaluate, b, context, sensitive, False{}, CaseUnresolved{}), u => union_result(analyze_using(~resolve, ~evaluate, c, context, sensitive, False{}, CaseUnresolved{}), union_result(analyze_using(~resolve, ~evaluate, a, context, sensitive, False{}, CaseUnresolved{}), analyze_using(~resolve, ~evaluate, b, context, sensitive, False{}, CaseUnresolved{})))))

def analyze_mode(expr: Core.Expr, +context: List<&2, Core.Binding>, +sensitive: Bool, +static: Bool, choice: CaseChoice) -> DependencyResult:
  analyze_using(~resolve_variable, ~Core.evaluate_in, expr, context, sensitive, static, choice)

def analyze(expr: Core.Expr, context: List<&2, Core.Binding>, sensitive: Bool, static: Bool) -> DependencyResult:
  analyze_mode(expr, context, sensitive, static, CaseUnresolved{})
