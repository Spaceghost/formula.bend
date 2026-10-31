import Base
import ../src/calculator.bend as Calculator
import ../src/parser.bend as Parser
import ../src/core.bend as Core

def field(input: Core.Value, name: String) -> Core.Value:
  Core.hash_get(input, Core.SymbolValue{name})

def default_hash(value: Core.Value) -> Core.Value:
  match value:
    case Core.NullValue{}:
      Core.HashNil{}
    case value:
      value

def boolean(value: Core.Value, fallback: Bool) -> Bool:
  match value:
    case Core.NullValue{}:
      fallback
    case value:
      Core.truthy(value)

def construct(+options: Core.Value) -> Calculator.State:
  Calculator.make(boolean(field(options, "case_sensitive"), False{}), boolean(field(options, "nested_data_support"), True{}), boolean(field(options, "cache_ast"), False{}))

def success(state: Calculator.State, value: Core.Value) -> Calculator.Evaluation:
  Calculator.Calculated{state, value}

def self_result(state: Calculator.State) -> Calculator.Evaluation:
  success(state, Core.TextValue{"self"})

def ast_result(parsed: Calculator.ParsedState) -> Calculator.Evaluation:
  match parsed:
    case Calculator.ParsedWith{state, Parser.Accepted{expression}}:
      success(state, Core.TextValue{"ast"})
    case Calculator.ParsedWith{state, Parser.ParseError{+message}}:
      Calculator.Rejected{state, Bool.pick(String, String.starts_with(message, "Tokenizer: "), "error:Dentaku::TokenizerError", "error:Dentaku::ParseError"), message}

def restore_cache(result: Calculator.Evaluation) -> Calculator.Evaluation:
  match result:
    case Calculator.Calculated{state, value}:
      success(Calculator.enable_cache(state), value)
    case Calculator.Rejected{state, snapshot, message}:
      Calculator.Rejected{Calculator.enable_cache(state), snapshot, message}

def pair_value(value: Core.Value, state: Calculator.State, key: Core.Value) -> Calculator.Evaluation:
  match value:
    case Core.NullValue{}:
      Calculator.Rejected{state, "error:NoMethodError", "Ruby's two-argument store overload requires a non-nil value"}
    case value:
      self_result(Calculator.set_value(state, key, value))

def clear_one(found: Maybe<&2, Core.Expr>, state: Calculator.State, source: String) -> Calculator.Evaluation:
  match found:
    case None{}:
      success(Calculator.clear_cache_key(state, source), Core.NullValue{})
    case Some{expression}:
      success(Calculator.clear_cache_key(state, source), Core.TextValue{"ast"})

def cache_description(cache: List<&2, Calculator.Cached>) -> Core.Value:
  match cache:
    case Nil{}:
      Core.HashNil{}
    case Calculator.AstEntry{key, expression} <> tail:
      Core.HashEntry{key, Core.TextValue{"ast"}, cache_description(tail)}

def loaded_cache(+state: Calculator.State, +cache: List<&2, Calculator.Cached>) -> Calculator.Evaluation:
  success(Calculator.load_cache(state, cache), cache_description(cache))

def clear_cache_key(key: Core.Value, +state: Calculator.State) -> Calculator.Evaluation:
  match key:
    case Core.NullValue{}:
      success(Calculator.clear_cache(state), Core.HashNil{})
    case Core.SymbolValue{"all"}:
      success(Calculator.clear_cache(state), Core.HashNil{})
    case Core.TextValue{+source}:
      clear_one(Calculator.cache_find(Calculator.get_cache(state), Core.TextValue{source}), state, source)
    case key:
      Calculator.Rejected{state, "error:ArgumentError", "Invalid cache selector"}

def warm_entry(key: Core.Value, parsed: Parser.Parsed, rest: List<&2, Calculator.Cached>) -> List<&2, Calculator.Cached>:
  match parsed:
    case Parser.Accepted{expression}:
      Calculator.AstEntry{key, expression} <> rest
    case parsed:
      rest

def warm_cache(entries: Core.Value, +sensitive: Bool) -> List<&2, Calculator.Cached>:
  match entries:
    case Core.HashEntry{key, Core.TextValue{source}, tail}:
      warm_entry(key, Parser.parse_in(source, sensitive), warm_cache(tail, sensitive))
    case entries:
      Nil{}

def execute(operation: Core.Value, +input: Core.Value, +state: Calculator.State) -> Calculator.Evaluation:
  match operation:
    case Core.TextValue{"store"}:
      self_result(Calculator.store_values(state, field(input, "values")))
    case Core.TextValue{"store_pair"}:
      pair_value(field(input, "value"), state, field(input, "key"))
    case Core.TextValue{"clear"}:
      success(Calculator.clear(state), Core.HashNil{})
    case Core.TextValue{"memory"}:
      success(state, Calculator.get_memory(state))
    case Core.TextValue{"empty"}:
      success(state, Core.Logical{Calculator.is_empty(state)})
    case Core.TextValue{"cache_keys"}:
      success(state, Calculator.get_cache_keys(state))
    case Core.TextValue{"cache_enabled"}:
      success(state, Core.Logical{Calculator.cache_enabled(state)})
    case Core.TextValue{"ast"}:
      ast_result(Calculator.ast(state, field(input, "expression")))
    case Core.TextValue{"evaluate"}:
      Calculator.evaluate_value(field(input, "expression"), state, default_hash(field(input, "data")), False{})
    case Core.TextValue{"evaluate!"}:
      Calculator.evaluate_value(field(input, "expression"), state, default_hash(field(input, "data")), True{})
    case Core.TextValue{"clear_cache"}:
      clear_cache_key(field(input, "key"), state)
    case Core.TextValue{"warm_cache"}:
      loaded_cache(state, warm_cache(field(input, "entries"), Calculator.case_sensitive(state)))
    case Core.TextValue{"disable_cache_status"}:
      success(Calculator.enable_cache(state), Core.Logical{Calculator.cache_enabled(Calculator.disable_cache(state))})
    case Core.TextValue{"disable_cache_eval"}:
      restore_cache(Calculator.evaluate_value(field(input, "expression"), Calculator.disable_cache(state), default_hash(field(input, "data")), True{}))
    case operation:
      Calculator.Rejected{state, "error:ArgumentError", "Unknown calculator operation"}

def record(+result: Calculator.Evaluation) -> Core.Value:
  +state = Calculator.result_state(result)
  Core.HashEntry{Core.TextValue{"result"}, Core.TextValue{Calculator.result_snapshot(result)},
  Core.HashEntry{Core.TextValue{"memory"}, Calculator.get_memory(state),
  Core.HashEntry{Core.TextValue{"cache"}, Calculator.get_cache_keys(state),
  Core.HashEntry{Core.TextValue{"empty"}, Core.Logical{Calculator.is_empty(state)},
  Core.HashEntry{Core.TextValue{"cache_enabled"}, Core.Logical{Calculator.cache_enabled(state)}, Core.HashNil{}}}}}}

def prepend_record(head: Core.Value, tail: Core.Value) -> Core.Value:
  Core.ArrayCons{head, tail}

def continue_commands(+result: Calculator.Evaluation, rest: Calculator.State -> Core.Value) -> Core.Value:
  prepend_record(record(result), rest(Calculator.result_state(result)))

def commands(values: Core.Value, state: Calculator.State) -> Core.Value:
  match values:
    case Core.ArrayCons{+head, tail}:
      continue_commands(execute(field(head, "op"), head, state), next => commands(tail, next))
    case values:
      Core.ArrayNil{}

def snapshot(+input: Core.Value) -> String:
  Core.snapshot(commands(field(input, "commands"), construct(field(input, "options"))))
