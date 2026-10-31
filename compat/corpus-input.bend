import Base
import ../src/core.bend as Core
import ./gpu-corpus.bend as Gpu

type Loaded is Data:
  LoadedWork{work: Gpu.Work}
  Invalid{message: String}

type Context is Data:
  Bindings{values: List<&2, Core.Binding>}
  InvalidContext{}

type NamedOperation is Data:
  Named{name: String, operation: Gpu.Operation}

def lookup_operation(entries: List<&2, NamedOperation>, +name: String) -> Maybe<&2, Gpu.Operation>:
  match entries:
    case Nil{}:
      None{}
    case Named{key, operation} <> rest:
      Bool.pick(Maybe<&2, Gpu.Operation>, String.eq(key, name), Some{operation}, lookup_operation(rest, name))

def operation(name: String) -> Maybe<&2, Gpu.Operation>:
  lookup_operation([
    Named{"evaluate", Gpu.Evaluate{}}, Named{"permissive", Gpu.Permissive{}},
    Named{"identifiers", Gpu.Identifiers{}}, Named{"dependencies", Gpu.Dependencies{}},
    Named{"class", Gpu.Class{}}, Named{"type", Gpu.StaticType{}},
    Named{"message", Gpu.Message{}}, Named{"coerce", Gpu.Coerce{}},
    Named{"coerce_class", Gpu.CoerceClass{}}, Named{"coerce_message", Gpu.CoerceMessage{}},
    Named{"resolve_order", Gpu.ResolveOrder{}}, Named{"resolve_cycles", Gpu.ResolveCycles{}},
    Named{"error_factory", Gpu.DescribeError{}}
  ], name)

# Wire pairs retain the Ruby insertion order; bindings put the last pair first.
def context(pairs: Core.Value, accumulated: List<&2, Core.Binding>) -> Context:
  match pairs:
    case Core.ArrayNil{}:
      Bindings{accumulated}
    case Core.ArrayCons{Core.ArrayCons{Core.TextValue{name}, Core.ArrayCons{value, Core.ArrayNil{}}}, rest}:
      context(rest, Core.Bound{name, value} <> accumulated)
    case Core.ArrayCons{Core.ArrayCons{Core.SymbolValue{name}, Core.ArrayCons{value, Core.ArrayNil{}}}, rest}:
      context(rest, Core.SymbolBound{name, value} <> accumulated)
    case pairs:
      InvalidContext{}

def checked(operation: Maybe<&2, Gpu.Operation>, context: Context, id: String, formula: String, sensitive: Bool, json: Bool) -> Loaded:
  match operation context:
    case None{} context:
      Invalid{"Unknown corpus operation"}
    case Some{operation} InvalidContext{}:
      Invalid{"Invalid corpus bindings"}
    case Some{operation} Bindings{values}:
      LoadedWork{Gpu.Leaf{Gpu.Check{id, formula, operation, values, sensitive, json}}}

def row(value: Core.Value) -> Loaded:
  match value:
    case Core.ArrayCons{Core.TextValue{id}, Core.ArrayCons{Core.TextValue{formula}, Core.ArrayCons{Core.TextValue{op}, Core.ArrayCons{pairs, Core.ArrayCons{Core.Logical{sensitive}, Core.ArrayCons{Core.Logical{json}, Core.ArrayNil{}}}}}}}:
      checked(operation(op), context(pairs, Nil{}), id, formula, sensitive, json)
    case value:
      Invalid{"Invalid corpus row"}

def combine(left: Loaded, right: Loaded) -> Loaded:
  match left right:
    case Invalid{message} right:
      Invalid{message}
    case left Invalid{message}:
      Invalid{message}
    case LoadedWork{a} LoadedWork{b}:
      LoadedWork{Gpu.Fork{a, b}}

def compile_batch(batch: Core.Value) -> Loaded:
  match batch:
    case Core.ArgumentValue{value}:
      row(value)
    case Core.ArgumentPair{left, right}:
      a b = compile_batch(left) compile_batch(right)
      combine(a, b)
    case batch:
      Invalid{"Empty or malformed corpus input"}

def load(value: Core.Value) -> Loaded:
  match value:
    case Core.ArrayCons{head, tail}:
      compile_batch(Core.collection_batch(Core.ArrayCons{head, tail}))
    case value:
      Invalid{"Corpus input must be a nonempty array"}
