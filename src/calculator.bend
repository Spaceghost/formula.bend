import ./dependencies.bend as Dependencies
import Base
import ./core.bend as Core
import ./parser.bend as Parser

# Persistent state: callers retain the state returned by each operation.
type Cached is Data:
  AstEntry{source: Core.Value, expression: Core.Expr, sensitive: Bool}

type State is Data:
  Calculator{memory: Core.Value, cache: List<&2, Cached>, sensitive: Bool, nested: Bool, cache_ast: Bool, disabled: Bool}

type ParsedState is Data:
  ParsedWith{state: State, parsed: Parser.Parsed, sensitive: Bool}

type Evaluation is Data:
  Calculated{state: State, value: Core.Value}
  Rejected{state: State, snapshot: String, message: String}

def make(sensitive: Bool, nested: Bool, cache_ast: Bool) -> State:
  Calculator{Core.HashNil{}, Nil{}, sensitive, nested, cache_ast, False{}}

def create() -> State:
  make(False{}, True{}, False{})

def get_memory(state: State) -> Core.Value:
  match state:
    case Calculator{memory, cache, sensitive, nested, cache_ast, disabled}:
      memory

def case_sensitive(state: State) -> Bool:
  match state:
    case Calculator{memory, cache, sensitive, nested, cache_ast, disabled}:
      sensitive

def nested_data(state: State) -> Bool:
  match state:
    case Calculator{memory, cache, sensitive, nested, cache_ast, disabled}:
      nested

def cache_enabled(state: State) -> Bool:
  match state:
    case Calculator{memory, cache, sensitive, nested, cache_ast, disabled}:
      Bool.and(cache_ast, Bool.not(disabled))

def with_memory(state: State, memory: Core.Value) -> State:
  match state:
    case Calculator{old, cache, sensitive, nested, cache_ast, disabled}:
      Calculator{memory, cache, sensitive, nested, cache_ast, disabled}

def clear(state: State) -> State:
  with_memory(state, Core.HashNil{})

def empty_memory(memory: Core.Value) -> Bool:
  match memory:
    case Core.HashNil{}:
      True{}
    case memory:
      False{}

def is_empty(state: State) -> Bool:
  empty_memory(get_memory(state))

# Updating a key preserves its first insertion position, as Ruby Hash#[]= does.
def put(memory: Core.Value, +key: Core.Value, +value: Core.Value) -> Core.Value:
  match memory:
    case Core.HashEntry{+old_key, old_value, +tail}:
      Bool.pick(Core.Value, Core.hash_key_equal(old_key, key), Core.HashEntry{old_key, value, tail}, Core.HashEntry{old_key, old_value, put(tail, key, value)})
    case memory:
      Core.HashEntry{key, value, Core.HashNil{}}

def memory_key(key: Core.Value, sensitive: Bool) -> String:
  Core.normalize(sensitive, Core.ruby_render(key, False{}, False{}))

def set_value(+state: State, key: Core.Value, value: Core.Value) -> State:
  with_memory(state, put(get_memory(state), Core.TextValue{memory_key(key, case_sensitive(state))}, value))

# Intermediate hash values remain in memory. Arrays remain whole values.
def store_nested(value: Core.Value, +prefix: String, memory: Core.Value, +sensitive: Bool) -> Core.Value:
  match value:
    case Core.HashEntry{key, +head, tail}:
      +name = prefix ++ "." ++ Core.ruby_render(key, False{}, False{})
      store_nested(tail, prefix, store_nested(head, name, put(memory, Core.TextValue{Core.normalize(sensitive, name)}, head), sensitive), sensitive)
    case value:
      memory

def optional_nested(nested: Bool, value: Core.Value, prefix: String, memory: Core.Value, sensitive: Bool) -> Core.Value:
  match nested:
    case True{}:
      store_nested(value, prefix, memory, sensitive)
    case False{}:
      memory

def store_pairs(values: Core.Value, memory: Core.Value, +sensitive: Bool, +nested: Bool) -> Core.Value:
  match values:
    case Core.HashEntry{key, +head, tail}:
      +name = memory_key(key, sensitive)
      store_pairs(tail, optional_nested(nested, head, name, put(memory, Core.TextValue{name}, head), sensitive), sensitive, nested)
    case values:
      memory

def store_values(+state: State, values: Core.Value) -> State:
  with_memory(state, store_pairs(values, get_memory(state), case_sensitive(state), nested_data(state)))

def get_cache(state: State) -> List<&2, Cached>:
  match state:
    case Calculator{memory, cache, sensitive, nested, cache_ast, disabled}:
      cache

def load_cache(state: State, cache: List<&2, Cached>) -> State:
  match state:
    case Calculator{memory, old, sensitive, nested, cache_ast, disabled}:
      Calculator{memory, cache, sensitive, nested, cache_ast, disabled}

def cache_keys(cache: List<&2, Cached>) -> Core.Value:
  match cache:
    case Nil{}:
      Core.ArrayNil{}
    case AstEntry{source, expression, origin} <> tail:
      Core.ArrayCons{source, cache_keys(tail)}

def get_cache_keys(state: State) -> Core.Value:
  cache_keys(get_cache(state))

def cache_find(cache: List<&2, Cached>, +source: Core.Value) -> Maybe<&2, Cached>:
  match cache:
    case Nil{}:
      None{}
    case AstEntry{+key, expression, origin} <> tail:
      Bool.pick(Maybe<&2, Cached>, Core.set_equal(source, key, True{}), Some{AstEntry{key, expression, origin}}, cache_find(tail, source))

def cache_append(cache: List<&2, Cached>, +source: Core.Value, +expression: Core.Expr, +origin: Bool) -> List<&2, Cached>:
  match cache:
    case Nil{}:
      AstEntry{source, expression, origin} <> Nil{}
    case head <> tail:
      head <> cache_append(tail, source, expression, origin)

def cache_remove(cache: List<&2, Cached>, +source: Core.Value) -> List<&2, Cached>:
  match cache:
    case Nil{}:
      Nil{}
    case AstEntry{+key, expression, origin} <> +tail:
      Bool.pick(List<&2, Cached>, Core.set_equal(source, key, True{}), tail, AstEntry{key, expression, origin} <> cache_remove(tail, source))

def clear_cache(state: State) -> State:
  load_cache(state, Nil{})

def clear_cache_key(+state: State, source: String) -> State:
  load_cache(state, cache_remove(get_cache(state), Core.TextValue{source}))

def disable_cache(state: State) -> State:
  match state:
    case Calculator{memory, cache, sensitive, nested, cache_ast, disabled}:
      Calculator{memory, cache, sensitive, nested, cache_ast, True{}}

def enable_cache(state: State) -> State:
  match state:
    case Calculator{memory, cache, sensitive, nested, cache_ast, disabled}:
      Calculator{memory, cache, sensitive, nested, cache_ast, False{}}

def remember(enabled: Bool, +state: State, source: Core.Value, expression: Core.Expr) -> State:
  match enabled:
    case False{}:
      state
    case True{}:
      load_cache(state, cache_append(get_cache(state), source, expression, case_sensitive(state)))

def parsed_new(parsed: Parser.Parsed, +state: State, source: Core.Value) -> ParsedState:
  match parsed:
    case Parser.Accepted{+expression}:
      ParsedWith{remember(cache_enabled(state), state, source, expression), Parser.Accepted{expression}, case_sensitive(state)}
    case Parser.ParseError{message}:
      ParsedWith{state, Parser.ParseError{message}, case_sensitive(state)}

# Reads consult an explicitly supplied cache even when new cache writes are off.
def ast_found(found: Maybe<&2, Cached>, +state: State, +source: Core.Value) -> ParsedState:
  match found:
    case Some{AstEntry{key, expression, origin}}:
      ParsedWith{state, Parser.Accepted{expression}, origin}
    case None{}:
      parsed_new(Parser.parse_in(Core.ruby_render(source, False{}, False{}), case_sensitive(state)), state, source)

def ast(+state: State, +source: Core.Value) -> ParsedState:
  ast_found(cache_find(get_cache(state), source), state, source)

def bindings(memory: Core.Value) -> List<&2, Core.Binding>:
  match memory:
    case Core.HashEntry{Core.TextValue{name}, value, tail}:
      Core.ScopedBound{name, value} <> bindings(tail)
    case memory:
      Nil{}

def has_mode(found: Maybe<&2, Core.Value>) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{value}:
      True{}

def evaluation_data(+data: Core.Value, strict: Bool) -> Core.Value:
  Bool.pick(Core.Value, has_mode(Core.hash_find(data, Core.SymbolValue{"__evaluation_mode"})), data, put(data, Core.SymbolValue{"__evaluation_mode"}, Core.SymbolValue{Bool.pick(String, strict, "strict", "permissive")}))

def permissive_value(value: Core.Value, state: State) -> Evaluation:
  match value:
    case Core.Failure{+message}:
      Rejected{state, Core.failure_snapshot(message), message}
    case value:
      Calculated{state, value}

def value_result(value: Core.Value, state: State, strict: Bool) -> Evaluation:
  match value strict:
    case Core.Failure{+message} True{}:
      Rejected{state, Core.failure_snapshot(message), message}
    case Core.Failure{message} False{}:
      permissive_value(Core.permissive_result(Core.Failure{message}), state)
    case value strict:
      Calculated{state, value}

def evaluate_ast(parsed: ParsedState, data: Core.Value, +strict: Bool) -> Evaluation:
  match parsed:
    case ParsedWith{+state, Parser.Accepted{expression}, origin}:
      value_result(Parser.evaluate_stored(expression, bindings(get_memory(store_values(state, evaluation_data(data, strict)))), origin), state, strict)
    case ParsedWith{+state, Parser.ParseError{+message}, origin}:
      Bool.pick(Evaluation, strict, Rejected{state, Bool.pick(String, String.starts_with(message, "Tokenizer: "), "error:Dentaku::TokenizerError", "error:Dentaku::ParseError"), message}, Calculated{state, Core.NullValue{}})

def array_finish(head: Core.Value, tail: Evaluation) -> Evaluation:
  match tail:
    case Calculated{state, values}:
      Calculated{state, Core.ArrayCons{head, values}}
    case Rejected{state, snapshot, message}:
      Rejected{state, snapshot, message}

def array_next(head: Evaluation, next: State -> Evaluation) -> Evaluation:
  match head:
    case Calculated{state, value}:
      array_finish(value, next(state))
    case Rejected{state, snapshot, message}:
      Rejected{state, snapshot, message}

def hash_finish(key: Core.Value, head: Core.Value, tail: Evaluation) -> Evaluation:
  match tail:
    case Calculated{state, values}:
      Calculated{state, Core.HashEntry{key, head, values}}
    case Rejected{state, snapshot, message}:
      Rejected{state, snapshot, message}

def hash_next(key: Core.Value, head: Evaluation, next: State -> Evaluation) -> Evaluation:
  match head:
    case Calculated{state, value}:
      hash_finish(key, value, next(state))
    case Rejected{state, snapshot, message}:
      Rejected{state, snapshot, message}

# Ordered cache updates retain source insertion order across bulk expressions.
# Independent formula arithmetic still runs through Core's parallel evaluator.
def evaluate_value(expression: Core.Value, state: State, +data: Core.Value, +strict: Bool) -> Evaluation:
  match expression:
    case Core.ArrayNil{}:
      Calculated{state, Core.ArrayNil{}}
    case Core.HashNil{}:
      Calculated{state, Core.HashNil{}}
    case Core.ArrayCons{head, tail}:
      array_next(evaluate_value(head, state, data, strict), next => evaluate_value(tail, next, data, strict))
    case Core.HashEntry{key, value, tail}:
      hash_next(key, evaluate_value(value, state, data, strict), next => evaluate_value(tail, next, data, strict))
    case expression:
      evaluate_ast(ast(state, expression), data, strict)

def result_state(result: Evaluation) -> State:
  match result:
    case Calculated{state, value}:
      state
    case Rejected{state, snapshot, message}:
      state

def result_snapshot(result: Evaluation) -> String:
  match result:
    case Calculated{state, value}:
      Core.snapshot(value)
    case Rejected{state, snapshot, message}:
      snapshot
def ast_mode(parsed: ParsedState) -> Bool:
  match parsed:
    case ParsedWith{state, result, origin}:
      origin
# Dependency queries share parsing/cache semantics but never write temporary data
# into the returned calculator. A nil context intentionally ignores memory.
def name_values(names: List<&2, String>) -> Core.Value:
  match names:
    case Nil{}:
      Core.ArrayNil{}
    case head <> tail:
      Core.ArrayCons{Core.TextValue{head}, name_values(tail)}

def query_context(static: Bool, data: Core.Value, state: State) -> List<&2, Core.Binding>:
  match static data:
    case True{} data:
      Nil{}
    case False{} Core.NullValue{}:
      Nil{}
    case False{} data:
      bindings(get_memory(store_values(state, data)))

def query_names(result: Parser.NamesResult, state: State) -> Evaluation:
  match result:
    case Parser.FoundNames{names}:
      Calculated{state, name_values(names)}
    case Parser.NamesError{+message}:
      Rejected{state, Bool.pick(String, String.starts_with(message, "Tokenizer: "), "error:Dentaku::TokenizerError", "error:Dentaku::ParseError"), message}

def dependency_static(value: Core.Value) -> Bool:
  match value:
    case Core.Logical{True{}}:
      True{}
    case value:
      False{}

def query_parsed(parsed: Parser.Parsed, +context: List<&2, Core.Binding>, +origin: Bool, static: Bool) -> Parser.NamesResult:
  match parsed:
    case Parser.Accepted{expression}:
      Parser.FoundNames{Dependencies.analyze(expression, context, origin, Bool.or(static, dependency_static(Core.lookup(context, "__static_dependencies", origin))))}
    case Parser.ParseError{message}:
      Parser.NamesError{message}

def query_ast(parsed: ParsedState, data: Core.Value, +static: Bool) -> Evaluation:
  match parsed:
    case ParsedWith{+state, expression, origin}:
      query_names(query_parsed(expression, query_context(static, data, state), origin, static), state)

def append_names(left: Core.Value, right: Core.Value) -> Core.Value:
  match left:
    case Core.ArrayCons{head, tail}:
      Core.ArrayCons{head, append_names(tail, right)}
    case left:
      right

def query_finish(head: Core.Value, tail: Evaluation) -> Evaluation:
  match tail:
    case Calculated{state, values}:
      Calculated{state, append_names(head, values)}
    case Rejected{state, snapshot, message}:
      Rejected{state, snapshot, message}

def query_next(head: Evaluation, next: State -> Evaluation) -> Evaluation:
  match head:
    case Calculated{state, values}:
      query_finish(values, next(state))
    case Rejected{state, snapshot, message}:
      Rejected{state, snapshot, message}

def query_value(expression: Core.Value, state: State, +data: Core.Value, +static: Bool) -> Evaluation:
  match expression:
    case Core.ArrayNil{}:
      Calculated{state, Core.ArrayNil{}}
    case Core.HashNil{}:
      Calculated{state, Core.ArrayNil{}}
    case Core.ArrayCons{head, tail}:
      query_next(query_value(head, state, data, static), next => query_value(tail, next, data, static))
    case Core.HashEntry{key, value, tail}:
      query_next(query_value(value, state, data, static), next => query_value(tail, next, data, static))
    case expression:
      query_ast(ast(state, expression), data, static)

def dependencies(expression: Core.Value, state: State, data: Core.Value) -> Evaluation:
  query_value(expression, state, data, False{})

def unique_name_pick(found: Maybe<&2, Core.Value>, head: Core.Value, skipped: Unit -> Core.Value, added: Unit -> Core.Value) -> Core.Value:
  match found:
    case Some{value}:
      skipped(Unit{})
    case None{}:
      Core.ArrayCons{head, added(Unit{})}

def unique_name_values(values: Core.Value, +seen: Core.Value) -> Core.Value:
  match values:
    case Core.ArrayCons{+head, +tail}:
      unique_name_pick(Core.hash_find(seen, head), head, u => unique_name_values(tail, seen), u => unique_name_values(tail, Core.HashEntry{head, Core.NullValue{}, seen}))
    case values:
      Core.ArrayNil{}

def identifiers_result(result: Evaluation) -> Evaluation:
  match result:
    case Calculated{state, names}:
      Calculated{state, unique_name_values(names, Core.HashNil{})}
    case Rejected{state, snapshot, message}:
      Rejected{state, snapshot, message}

def identifiers(expression: Core.Value, state: State) -> Evaluation:
  identifiers_result(query_value(expression, state, Core.HashNil{}, True{}))
