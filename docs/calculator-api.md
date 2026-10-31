# Calculator state and cache

`src/calculator.bend` provides persistent calculator state over supported value
types. Operations return new state; evaluation returns `Calculated{state, value}`
or `Rejected{state, snapshot, message}`. Keep the returned state to retain cache writes.

`make(case_sensitive, nested_data_support, cache_ast)` configures the instance.
`create()` uses false, true, false respectively. These Boolean options do not yet
inherit mutable module-level defaults from a global registry.

## Memory

`store_values` stores a hash, normalizes keys, and optionally flattens nested
hashes while retaining intermediate objects. Arrays remain whole values.
Existing keys retain their insertion position. Updating a parent does not
remove previously flattened descendant keys.

`set_value` is the explicit binding primitive and does not flatten its value.
The compatibility adapter preserves Ruby's overloaded `store`: a nil second
argument selects hash or Enumerable storage, so `store(hash, nil)` remains valid.
Array-pair inputs work when nested-data support is disabled. With that option
enabled, Ruby's `each_value` call rejects arrays. Missing pair elements become
nil; extra elements are ignored. Other Enumerable types still need coverage.

`get_memory`, `is_empty`, and `clear` inspect or replace memory. Clearing memory
retains the AST cache. Evaluation data temporarily overrides memory, including
on failures, and does not become persistent memory.

## Parsing and evaluation

`ast` returns a parsed expression, its creator's case mode, and updated state.
Cache keys retain the original supported scalar input type. Reads consult
prewarmed entries even when new writes are disabled. Parse failures are not
cached; accepted expressions remain cached when their evaluation fails.

`evaluate_value` supports scalar, array and hash expressions. Strict mode stops
bulk evaluation at its first error. Permissive mode suppresses Dentaku errors
for each child; native bounds errors still propagate. Hash keys and nested
collection shape are retained.

Arithmetic uses the engine's parallel evaluator. Ordered cache updates let
later children observe prior cache writes.

## Cache operations

`get_cache`, `get_cache_keys`, `load_cache`, `clear_cache`, and `clear_cache_key`
manage typed AST entries. `AstEntry` contains the original key, `Core.Expr`, and
the creator's case-sensitive flag. These are parsed programs, not formula strings.
Loading a cache replaces the previous cache; a key may refer to a program parsed
from a different source.

Transferred programs retain their creator's case mode. Prepared memory bindings
keep their already-normalized keys exact. Evaluation does not normalize those
keys a second time under the program's mode. Identifier, Unicode, MAP and REDUCE
transfer cases are checked in both directions.

`disable_cache` suppresses writes; `enable_cache` ends that state. The adapter's
disabled-evaluation operation restores the enabled state after success or failure.

## Remaining API work

Stored formulas, custom functions, aliases, error-handler callbacks, bulk solving,
formula-aware dependency analysis and regex cache invalidation remain unfinished.
Direct mutable identity and hand-assembled Ruby ASTs with mixed per-node case
modes are not modeled. Float, date/time and arbitrary Ruby object inputs remain
outside this value profile.

Session probes record results, memory, cache keys, emptiness and cache-enabled
state after every operation. Golden results are adopted only after Bend agrees
with the pinned Ruby implementation.

All 51 original Calculator sessions pass Bend 2.0.16 on frozen c852ba4 source:
eight preserved results and 43 resumed results match the Ruby oracle. Its checker
peaked near 30 GiB; a separate 16 GiB diagnostic hit its compiler cap. These are
checker resource results, not formula runtime memory measurements. The newer 128
transfer/storage sessions are verified on 2.0.39. See [numeric limits](numeric-limits.md)
for the separate Ruby huge-shift allocation exception gap.
