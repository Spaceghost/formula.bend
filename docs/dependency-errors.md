# Dependency errors and guard evaluation

The dependency analyzer returns `DependencyResult`, with either
`AnalysisNames{names}` or `AnalysisNativeError{class_name, message}`. Callers
must preserve the error outcome. An error is not an empty dependency list.
The name payload retains the existing duplicate and ordering rules: argument
collections preserve duplicates, while arithmetic and logical unions remove
them. The existing duplicate-name law still asserts the same two names, now
inside the successful result constructor.

Dynamic IF analysis evaluates its guard and visits the selected branch. A
Dentaku error falls back to the complete dependency union. A native Ruby error
escapes with its class and message. CASE applies the same distinction to its
switch and matching keys; later clauses are not entered after a native failure.
Logical operators collect both sides' dependencies before probing eligible,
fully bound operands. A rescued Dentaku error returns the already collected
union; a native error propagates. Static analysis never probes a guard.

An exact Boolean true `__static_dependencies` binding enables static traversal.
Numeric truthiness does not enable it. Syntactic identifier queries additionally
remove duplicate names; dependency queries retain each node's ordinary rules.
The direct parser, Calculator queries, stored dependency queries and checked
stored execution all preserve native failures. Calculator query failures also
stop bulk queries and retain only cache entries that Ruby would have reached.

Comparison nodes have their own rescue boundary. Native ArgumentError and
TypeError from an operand become Dentaku argument errors; native RangeError and
FloatDomainError remain native. A native error on the left of a logical
expression cannot be recovered by a decisive right operand. This holds even
when a static dependency context disables dynamic probes.

The dedicated differential corpus includes 1,350 formula/API probes, 96
Calculator sessions and 216 stored-expression probes. It covers IF, CASE,
logical probes, nested branches, error precedence, classes/messages, static
markers and cache effects. This is evidence for the represented built-ins and
value types. Callable bindings, volatile custom functions and complete
Calculator integration remain part of the broader parity work.
