# Stored expressions

Stored expressions are typed AST values. The direct execution API lives in
src/stored.bend. Calculator dependency preflight and its evaluation entry points
are not yet connected to this runner.

Core.StoredExpression contains an expression and its creator's case mode.
Stored.evaluate_in evaluates an expression against prepared bindings. Identifier
lookup expands a stored AST using the current context and the stored creator's
mode. Ordinary values keep their existing lookup behavior.

Run the example with bend examples/stored.bend. It stores a * 3 as f, binds a to
2, evaluates f + 1, and prints number:7. Parser.parse_in can produce an expression
from source; handle its Accepted or ParseError result before constructing a
stored value.

Stored execution shares the total evaluator's traversal, arithmetic, lazy
branches and balanced enumeration machinery through a resolver template.
Parallel branches receive reusable contexts. MAP and REDUCE local bindings
remain visible inside stored expressions. A stored program starts its own CASE
subject scope.

Recursive stored programs have no fixed depth cutoff. The runner uses Bend's
unsafe recursion and is outside termination proofs. PROOF.bend imports the
shared total core and representation laws; it does not import the recursive
runner. Do not interpret a passing law gate as proof that every user program
terminates.

The separate stored-value corpus compares direct Ruby AST value execution,
rather than Calculator.evaluate! dependency preflight. It includes long chains,
local-binding recursion, case-mode transfers, lazy branches and collection
operations. Run make stored-check with the configured Bend, Lua and Bun tools.

Formula-aware dependency expansion, the Calculator entry points, identifier
memoization, callable bindings, mutable identity and raw Ruby AST reflection
remain unfinished. The stable ast snapshot is a fixture descriptor, not a Ruby
object serialization.

# Dependency queries and checked evaluation

src/stored_dependencies.bend expands stored AST dependencies through current
bindings. It uses the stored evaluator for guards and preserves duplicate and
binder rules from the shared analyzer.

src/stored_checked.bend provides dependency preflight followed by value
execution. Missing names are reported before value evaluation and retain Ruby's
first-occurrence order. An exact Boolean true static-dependency context marker
visits every branch while bound identifiers remain satisfied.

These are low-level AST entry points. Calculator state/cache evaluation entry
points are not yet connected. Native guard-error propagation and the other
remaining parity work still require completion.
