# Calculator state and cache

`src/calculator.bend` provides persistent calculator state over the engine's
supported value types. Each operation returns a new state; evaluation returns
`Calculated{state, value}` or `Rejected{state, snapshot, message}`.
Keep the returned state to retain AST cache writes.

`make(case_sensitive, nested_data_support, cache_ast)` configures the instance.
`create()` uses false, true, false respectively. These explicit Boolean options
do not yet inherit mutable module-level defaults from a global registry.

## Memory

`store_values` stores a hash, normalizes its keys, and optionally flattens nested
hashes while retaining intermediate objects. Arrays remain whole values.
Existing keys retain their insertion position. Updating a parent does not
remove previously flattened descendant keys.

`set_value` is the explicit binding primitive and does not flatten the supplied
value. The compatibility adapter models Ruby's overloaded two-argument
`store`: a nil second argument does not select that overload. Store nullable
bindings through a hash when matching Ruby's API.

`get_memory`, `is_empty`, and `clear` inspect or replace memory. Clearing
memory retains the AST cache. Evaluation data temporarily overrides memory,
including on failures, and does not become persistent calculator memory.

## Parsing and evaluation

`ast` returns a parsed expression and updated state. Cache keys retain the
original supported scalar input type. Reads consult prewarmed cache entries
even when new cache writes are disabled. Parse failures are not cached;
valid parsed expressions remain cached when their evaluation fails.

`evaluate_value` supports scalar, array and hash expressions. Strict mode
stops a bulk evaluation at its first error. Permissive mode suppresses Dentaku
errors for each child, but native bounds errors still propagate. Hash keys,
nested collection shape, and ordered cache updates are retained.

Arithmetic inside each expression uses the engine's parallel evaluator.
Bulk cache updates follow source order so later children observe prior cache
writes.

## Cache operations

`get_cache`, `get_cache_keys`, `load_cache`, `clear_cache`, and
`clear_cache_key` expose typed AST cache management. Cached entries contain
`Core.Expr`, not formula strings. Loading a cache replaces the previous cache.
An entry may deliberately bind one cache key to an expression parsed from
another source.

`disable_cache` suppresses new writes; `enable_cache` ends that state.
The adapter's disabled-evaluation operation restores the enabled state after
success or failure, matching Ruby's block form.

## Remaining API work

Stored formula bindings, custom function registration and callbacks, aliases,
bulk solving, identifiers/dependencies over stored formulas, and cache
invalidation by regular expression remain unfinished. Direct mutable memory
and cache identity are not modeled by persistent values. Float, date/time and
arbitrary Ruby object inputs remain outside this value profile.

The session probe generator records results, memory, cache keys, emptiness,
and cache-enabled state after each operation. Reference results are adopted
only after a complete Bend run agrees with the pinned Ruby implementation.

Cross-mode AST transfers between calculators and Ruby AST object identity
remain incomplete. The current prewarming probes parse entries for the
receiving calculator's case mode.

The Bend 2.0.39 gate checks every Calculator session. Legacy Bend 2.0.16
verification is partial: eight sessions passed in a batch whose checker
peaked near 30 GiB. A subsequent single-session diagnostic exceeded its
16 GiB compiler cap. This is a checker resource result, not a measurement
of formula runtime memory. See [numeric allocation limits](numeric-limits.md)
for the separate Ruby huge-shift exception gap.
