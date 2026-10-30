# Dentaku parity gates

Baseline: rubysolo/dentaku at 1b9950be405ecb0d425f8683447b58cf29796d1f.
The goal is behavioral parity with its rules, tests, and implementation. The
Bend regression suite is supporting evidence; it does not replace that baseline.

The inventory lists every upstream spec file. `partial` means some related
behavior exists, not that the upstream file passes against Bend. `unassessed`
means it still needs a rule-by-rule port. Source example-line counts do not
count dynamically generated examples. The executed RSpec JSON catalog is the
authoritative upstream runtime inventory.

## Required rule families

1. Tokenization and parsing: literals, exponents, hex, aliases, operators and
   precedence/associativity, strings, arrays, access, CASE, custom functions,
   exact rejection rules, and diagnostics.
2. Values and built-ins: numeric types/coercions, null, Ruby truthiness, lazy
   logic, arrays, strings, date/time, rounding, all registered built-ins,
   arity/type rules, and failure behavior.
3. Calculator API: evaluate versus evaluate!, store/bind, temporary contexts,
   case sensitivity, aliases, caching, custom functions, and registration.
4. Analysis: syntactic identifiers, resolution-aware dependencies, branch
   pruning, volatile functions, cycles, bulk solving, visitors and formatting.
5. Verification: port each upstream scenario or document an explicit language
   adaptation; run differential cases against the pinned Ruby implementation.
   Any unsupported case remains a failing or explicitly incomplete parity item.

## Shootout gate

Performance comparisons begin after the shared parity corpus passes. Use the
same formulas, bindings, expected values/errors/dependencies, work counts, and
numeric profile on every backend. Benchmark parsing, cached AST evaluation,
independent batches, and dependency-driven recalculation separately.

Targets: JavaScript; native CPU with one thread and multiple threads; CUDA; Metal.
Metal execution on Linux through a translation runtime is a candidate route;
record its translator revision, compiler, precision settings, and Vulkan driver
separately from Apple's native Metal runtime. A Mac is not a project prerequisite.
Record compiler/runtime versions, hardware, memory, thread counts, GPU use and
fallback status, workload and sizes, warmup, repetitions, timings, and result
checksums. Include Ruby Dentaku as a baseline. Report unsupported hardware as
unmeasured. A CPU fallback must never be labeled a GPU measurement. Do not claim
speedups from different precision, omitted work, or skipped compatibility cases.

## Current evidence

The unchanged upstream suite passes 713 examples with zero failures and 96.82%
line coverage in the Ruby reference environment. `reference-summary.json` and
`upstream-spec-catalog.json` record that run. These results describe Ruby only.

The Lua-driven value and dependency corpus has 1462 cases matched against Ruby values or parse
error classification. It covers truthiness, strings/null, comparisons, selected
numeric-string coercions, and static operand rejection. It is a small subset of
the upstream catalog. Native error classes/messages, all calculator methods,
complete array semantics, other built-ins, custom functions, complete dependency graphs, and
visitors still require parity work. Hex/exponent numeric-string coercion is
covered within the documented exponent range. No spec family is marked complete
merely because this subset passes.

The static analysis pass never evaluates guards or functions. It distinguishes
literal strings rejected as arithmetic operands from variables that can resolve
to numeric strings. Validation visits unused branches too, matching parse-time
rejection independently of evaluation-time branch laziness.

## Reference runner

`tools/reference.Containerfile` pins the Ruby image manifest and adds Git for the
gemspec checks. Build it with chroot isolation on this host to avoid the observed
systemd container-creation stall. The oracle gems are installed in a mounted
cache: concurrent-ruby 1.3.5, rspec 3.13.0, pry 0.15.2, simplecov 0.22.0, and their
resolved dependencies. Keep the upstream checkout in a separate Git worktree.

```sh
lua tools/run-reference.lua UPSTREAM_WORKTREE GEMS_DIR CONTAINER_STORAGE RUNROOT
lua tools/upstream-inventory.lua UPSTREAM_WORKTREE
```

The runner mounts the actual Git common directory and runs the complete spec
suite without preloading Dentaku ahead of SimpleCov. Runtime outputs and coverage
stay in the upstream worktree. The application implementation remains Bend, and
the fixture generator and reference orchestration are Lua.

To refresh scalar oracle results after generating the corpus, run:

```sh
lua tools/run-oracle.lua PROJECT UPSTREAM GEMS STORAGE RUNROOT OUTPUT
```

The probe catches Dentaku errors and records their class; unexpected Ruby failures
abort without replacing the output. Compare the result before updating committed
goldens. Parser snapshots currently preserve parse-error classification, while
full runtime error-class/message parity remains unfinished. The 1462-case value and dependency
corpus passes on JavaScript; the 951-case checkpoint passed native CPU with one
and eight threads. This is correctness verification,
not the requested performance shootout.

The upstream catalog and scenario inventory derive from MIT-licensed Dentaku;
its license is retained as LICENSE.dentaku. The current pinned source has 54 spec
files and 713 executed examples. The inventory status remains partial or
unassessed until the corresponding rules have been ported and verified.

## Logical operators and dependency preflight

The corpus includes equal-precedence, left-associative infix AND/OR/XOR, prefix
NOT below comparisons, `!`, spacing-sensitive aliases, and static type rejection.
AND/OR can accept a decisive right operand when the left is unbound. A non-unbound
error is not suppressed. Calculator-style dependency preflight runs before value
evaluation; direct AST evaluation remains separate. Division validates its right
operand first, including zero, as in the pinned implementation.

Identifiers enumerate and deduplicate every syntactic input without executing
values. Dependencies prune resolvable IF branches and decisive AND/OR operands,
and conservatively retain inputs when probing a guard fails. Stored formula
nodes, volatile functions, custom function side effects, cycles, and bulk graph
solving remain incomplete. Logical function calls have eager argument collection
in Ruby and must not be implemented as aliases for the lazy infix operators.

Function calls now retain explicit argument nodes. Function dependencies can
retain repeated names, identifiers deduplicate them, and enclosing binary
operators deduplicate their combined dependencies. These cases are in the
differential corpus. Full visitor APIs and array arguments remain unfinished.

## Function argument collection

SUM, MUL, MIN, MAX, AVG, ABS, AND, OR, and XOR retain call nodes. Their arguments
are collected in balanced trees, with original ordering retained for errors and
dependencies. Numeric reductions also use balanced trees. The standard functions
collect argument values before validation; XOR validates logical arguments during
collection, matching the custom upstream node. AND/OR can skip a later value's
type check after a decisive value, but cannot skip an error from evaluating an
argument. Function dependencies do not prune such arguments.

The corpus includes empty-call behavior: MIN/MAX return null, SUM/MUL/AVG/AND/OR
raise runtime argument errors, and empty XOR is a parse error. XOR's static result
type follows the pinned custom-node implementation rather than being inferred
from its returned Boolean value. Numeric aggregates flatten nested arrays while
COUNT counts a single array's outer length and multiple arguments without
evaluating their values. Dependencies are still checked before COUNT evaluation.

The 114-case corpus passes on JavaScript and native CPU with Bend 2.0.16 and
2.0.39. Native checks run from frozen Git worktrees, with source commit and
artifact checksums recorded in backend-verification.json. The parser uses the
internal constructor ParseReady to avoid a collision with the newer Base library.
CUDA and Metal are still unverified; this is not a performance shootout.

## Arrays, indexing, and COUNT

The expanded 234-case corpus covers nested array values, aggregate flattening,
concatenation, subtraction, repetition, equality, array/string access, negative
and fractional indexes, null access, and all seven COUNT spec scenarios. Bound
values include exact decimals and nested arrays; case sensitivity and resolved
dependencies are exercised with the same contexts in Ruby and Bend.

Snapshots frame each array element by its Unicode character length, preserving
nesting and distinguishing embedded delimiters in strings. The oracle records
the pinned Access node's raw RangeError for signed-long index overflow. Parser
quirks are fixtures too: a two-element open array can be consumed at EOF, and an
empty array after an existing operand can leave too few operands for its parent.
These cases preserve observed behavior, not a general promise of complete parser
diagnostics. Full TokenizerError classification remains unfinished.

Array repetition currently narrows decimal counts with at most 14 integer digits;
larger counts return an argument error. Numeric representation/class parity,
hash/member access, custom indexable objects, ranges, and all array-oriented
built-ins remain incomplete. The 234-case checkpoint passes native CPU with one
and eight threads using Bend 2.0.39; its frozen source commit and artifact checksum
are recorded in backend-verification.json.

## Numeric literal and coercion rules

Scientific and hexadecimal literals use exact decimal coefficients. The corpus
includes large values, signed exponents, leading exponent zeros, hexadecimal
prefix casing, arithmetic, comparisons, and numeric strings. Leading, trailing,
and internal whitespace is rejected by numeric-string coercion. Malformed
numeric-looking words such as `1e`, `0xG`, and `123abc` retain Dentaku's identifier
fallback, including spelling; they are not uniformly tokenizer errors.

Scientific exponents currently narrow at most 14 significant exponent digits to
Nat. Extremely large scales and coefficients still depend on available memory;
infinities, complete Ruby numeric classes, and global BigDecimal
modes remain incomplete. The 296-case numeric literal checkpoint passes native
CPU with one and eight threads. The following 370-case class/coercion checkpoint
also passes both native thread counts.

## Numeric result classes

The corpus includes 74 numeric class and direct-coercion checks. Parsed integer
and hexadecimal coefficients retain Integer identity beyond the compact Nat
range; negative integers are distinct from negative decimals. Mixed arithmetic
retains BigDecimal identity even when its result is integral or zero. Division
and AVG return BigDecimal results, and rounding follows the input class and
precision. Explicit context tags preserve integral BigDecimal inputs.

These checks cover the pinned NumericParser string scenarios and its rejection
cases through the direct Core.require_numeric adapter. They do not establish
Ruby Float, Rational, non-finite values, subclass behavior,
or complete error metadata compatibility. Full parity remains incomplete.

## String functions and SWITCH

LEFT, RIGHT, MID, LEN, FIND, SUBSTITUTE, CONCAT, CONTAINS, and SWITCH are covered
by 131 additional cases, including AST result types and selected exact error
messages. MID validates its offset before evaluating its length. CONTAINS
evaluates the haystack before the needle. SWITCH retains eager argument values,
matches only keys, and returns the first match or an optional default.

String conversion distinguishes integers from BigDecimal scientific notation,
renders null as an empty string, and uses Ruby-style inspection for arrays.
Array inspection escapes control characters and interpolation markers.
SUBSTITUTE replaces the first match and handles ordinary Ruby replacement
backreferences. Regex values, named capture references, arbitrary Ruby objects,
invalid encodings, and complete String compatibility remain unimplemented.

The scenario map records all 40 string-function and five SWITCH example titles,
in addition to COUNT and NumericParser. Each entry references existing cases;
the map is checked by make parity-check. This is scenario correspondence through
language adapters, not an execution of all 713 upstream tests against Bend.
The 501-case string-function checkpoint passes native CPU with one and eight
threads; its source commit and artifact checksum are recorded.

## Signed decimal zero

The additional 49 cases preserve negative BigDecimal zero through literals,
numeric strings, arithmetic, division, positive-precision rounding, and string
conversion. Integer zero is unsigned. Scalar comparisons, array equality,
subtraction, and indexes treat both zero signs as equal. MIN/MAX keep the first
equal value's sign. SUM and AVG retain Ruby's initial positive integer zero;
MUL retains its initial integer one. These initial values matter for zero signs.
The 550-case signed-zero checkpoint passes native CPU with one and eight threads.

## CASE statements

The additional 42 cases cover nested CASE statements, expression switches,
literal and array keys, first-match behavior, lazy results and later keys,
static validation, case sensitivity, errors, and dependency analysis. Keys use
Ruby equality without numeric-string coercion. A missing match without ELSE
returns the pinned argument error and message.

The evaluator keeps case subjects in an internal value stack, separate from
user bindings. Recursion remains structural, with no evaluation fuel limit or
unsafe recursion. Static inspection visits every branch without executing guards.
Dependency analysis can select a resolvable branch, but a failed switch or WHEN
probe retains all branch dependencies, including earlier branches and duplicates.

Five behavioral CASE spec scenarios are mapped; Ruby constructor-shape errors
are not yet mapped. Visitors, volatile/custom-function purity, and complete
diagnostics remain incomplete. The 592-case checkpoint passes native CPU with
one and eight threads. Generated corpus output is grouped into small IO functions to avoid
the older compiler's stack limit on a single long IO chain.

## Collection expressions

MAP, FILTER, ALL, ANY, and REDUCE add 62 differential cases. They cover scalar,
null, empty, nested and array-valued inputs; scoped identifiers; case sensitivity;
result types; dependency pruning; binder validation; errors; and lazy ALL/ANY.
REDUCE starts with the explicit initial value or null, even for an empty input.
Item bindings shadow outer bindings without changing the caller's context.

The total evaluator recurses structurally over the expression and collection
tree. It has no execution fuel limit or unsafe recursion. Collections and function
arguments use contiguous balanced halves. MAP/FILTER and numeric aggregate
subtrees expose independent work to Bend's scheduler. ALL/ANY preserve lazy
source order; REDUCE threads its memo sequentially. Seven additional oracle
checks over 1,025-item collections exercise these paths without giant literals.
Both Bend 2.0.16 and 2.0.39 pass all 654 main cases and seven scale checks on
JavaScript. The proof gate contains 32 laws and the concrete suite 165 fixtures.

The 654-case checkpoint and seven scale checks pass native CPU with one and eight
threads. Its 32 laws also pass Bend 2.0.39's --verdict check against the kernel
built with Lean 4.34.0. Source commits and hashes are recorded separately from
the current work; this is correctness evidence, not a performance shootout.

## Hash bindings and permissive evaluation

Ordered hashes preserve distinct string and symbol keys, nested values, class
identity, indexing, equality independent of insertion order, COUNT, and Ruby-style
conversion for ordinary symbol names. Array(hash) enumerates key/value pairs.
Calculator contexts flatten nested hashes with intermediate values. Collection
item contexts preserve raw field case, shadow matching outer fields, and retain
outer flattened fields absent from the current item.

Parser.evaluate retains strict evaluate! semantics. Parser.evaluate_permissive
implements evaluate semantics: MAP, ALL, and ANY recover item errors as null;
FILTER and REDUCE propagate them to the outer recovery boundary. Caller-provided
symbol evaluation-mode overrides are preserved. Dependency-only probes do not
inject an evaluation mode. Raw signed-long RangeError remains observable.

The 79 new differential cases exercise these rules against Ruby. The 733-case
checkpoint and seven scale checks pass native CPU with one and eight threads.
Its 35 laws pass Lean-backed kernel verification. Typed fixture hashes accept
ordered string/symbol keys; arbitrary Ruby object keys, encodings, and complete
symbol inspection remain unfinished. The upstream families remain partial.

## Member access, PLUCK, and Unicode

The 149 additional cases cover indexed/function/grouped member access, chains,
operator binding, nil safety, missing-key messages, dotted-key hints, strict
case matching, and exact string/symbol key precedence. All 22 upstream member
scenarios are mapped. Ruby's MemberAccess subclass is represented by Access
with a typed MemberIndex; a concrete AST fixture checks that adaptation.

PLUCK validates the whole collection before evaluating defaults. It stringifies
hash keys with the last matching key winning, preserves null values, and eagerly
evaluates the default for every item even when the selected key exists. Empty
collections skip default evaluation while retaining dependency preflight. All
six upstream PLUCK scenarios are mapped. These mappings bring the total to 113.

Unicode tables record Ruby 3.3.13's Unicode 15.0 alpha/word properties, lowercase
mappings, and full case folding. Root binding normalization uses lowercase;
member fallback matching uses full folding. Combining marks, non-Latin names,
Turkish dotted I, Greek sigma, ligatures, and sharp S have differential checks.
Generated lookups use balanced branches and an ASCII fast path. The checked-in
tables come from reference runtime queries, not hand-maintained approximations.
Run tools/run-unicode-reference.lua STORAGE RUNROOT OUTPUT to regenerate the
reference table, then tools/generate-unicode.lua INPUT OUTPUT. make unicode-check
verifies generated source reproducibility.
The Unicode data notice is retained in LICENSE.unicode; unicode-profile.json
records table counts and source hashes.

Symbol rendering covers method names, operators, ordinary globals, instance and
class variables, and quoting for dotted or invalid identifiers. Non-printable
Unicode inspection, alternate encodings, and arbitrary Ruby values remain open.
Behavioral references include Ruby's
[symbol-name rules](https://github.com/ruby/ruby/blob/v3_3_13/symbol.c) and
[symbol inspection](https://github.com/ruby/ruby/blob/v3_3_13/string.c).
The later 951-case checkpoint includes these cases and passes native CPU with
one and eight threads at -O3.
The full 882-case corpus has also been replayed against Ruby after the typed
context encoding change, with no differences. The current proof gate contains
37 laws and the concrete suite 166 fixtures. Both Bend 2.0.16 and 2.0.39 pass
the full checks; Bend 2.0.39 also passes the 37 laws with --verdict.

## Modulo

The additional 69 cases cover exact BigDecimal remainder, negative operands,
positive zero, large coefficients, unequal decimal scales, numeric strings,
precedence, dependencies, static rejection, and collection bodies. Modulo returns
BigDecimal identity for integer inputs too. The evaluator validates the right
operand and rejects a zero divisor before entering the left expression. Three
new laws preserve this order, bringing the proof gate to 40 laws.

The tokenizer distinguishes binary modulo positions from postfix percentage.
Postfix percentage remains explicitly unsupported until Ruby Float arithmetic is
implemented. A negative divisor therefore needs parentheses, as in the pinned
source grammar. The three original FILTER/ALL/ANY binder-rejection formulas now
have direct differential cases; the scenario map contains 116 entries.

The native -O3 build of the 882-case checkpoint caused heavy paging and was
stopped with its generated C preserved. A second build with -O1 and inlining
disabled also exhausted available memory and was stopped; neither is a verified
native result. The generated Unicode lookups now use direct Boolean dispatch
instead of thousands of closures. Their reference tables and mappings are
unchanged. The revised 951-case corpus and seven scale checks pass native CPU
with one and eight threads at -O3.
Both Bend 2.0.16 and 2.0.39 pass the 951-case full checks; Bend 2.0.39 also passes
all 40 laws with --verdict. Native orchestration now completes C generation
before launching clang, so the compiler heaps do not overlap, and retains the
generated C for inspection.

## Quoted identifiers, comments, and fixture transport

The 132 additional cases cover quoted identifiers with spaces, punctuation,
reserved words, Unicode, empty names, and control characters. Quoted names stay
variables, including quoted true/false/null; quoted function calls retain the
source parse error. All three corresponding calculator scenarios are mapped,
bringing the map to 119 entries.

Comment stripping follows the pinned raw-text rule: complete /*...*/ spans are
removed before tokenization, including inside strings and quoted identifiers.
Adjacent text joins with no inserted whitespace. Incomplete comments remain
verbatim. Empty and comment-only formulas produce null. The two additional laws
preserve empty-comment prefixes and empty-formula evaluation for any context.
The proof book now imports the parser as well as the evaluator.

Formula text in the oracle transport is JSON encoded, with an explicit format
tag and support for the older five-column input. Optional json_ operation
prefixes frame canonical snapshots as JSON strings. This permits exact fixtures
for NUL, newlines, tabs, all ASCII controls, nested array text, and diagnostics
without corrupting TSV rows. The full 951-case reference corpus was replayed
after the formula encoding change with no differences.

Missing-variable messages now match Ruby's wording, normalized identifier case,
and ordered deduplication. Scoped missing fields and names containing control
characters have exact message checks. Legacy unbound failures still retain their
class and logical recovery behavior. Structured diagnostics and complete error
metadata remain unfinished. The proof gate contains 42 laws and the concrete
suite 169 fixtures. The 1,083-case checkpoint and seven scale checks pass native
CPU at `-O3` with one and eight threads; artifact hashes are recorded in
`backend-verification.json`.
Both Bend 2.0.16 and 2.0.39 pass the full checks. Bend 2.0.39 also passes the
42-law proof book with --verdict, including the imported parser implementation.

## Bitwise operators and array set rules

The next 379 reference-matched cases add integer OR, AND, left and arithmetic
right shifts, Boolean/null overloads, and array union/intersection. All four
operators retain the source's precedence zero and left associativity. Both
operands are evaluated before Boolean/null operations. Static type inspection
and dependency traversal include both children. The parser's bitwise OR
scenario is mapped, bringing the scenario correspondence count to 120.

Integer operations use arbitrary-length signed bit lists with infinite sign
extension. Negative counts reverse shifts; fractional BigDecimal shift counts
truncate toward zero, while BigDecimal OR/AND operands retain their source type
errors. Huge right shifts saturate to zero or minus one. Huge left shifts check
the pinned 64-bit Ruby allocation-width rule before building padding, preserving
the native RangeError and its exact message. Zero shifted by a huge count stays
zero. No fixed integer width or evaluation fuel was introduced.

Array set operations preserve first-occurrence ordering and remove duplicates.
Their equality is directional: Integer#eql? rejects BigDecimal, whereas the
pinned BigDecimal#eql? accepts equal Integers. Ruby's size-dependent hash paths
also distinguish numeric classes and signed decimal zero; nested arrays and
hashes follow these rules recursively. The same distinctions fix array
subtraction. Boundary checks cover total union lengths 16 and 17, and both
operands around the intersection/subtraction threshold. Typed decimal contexts
now preserve negative zero before evaluation instead of parsing it as an
Integer first.

Six concrete tokenizer fixtures cover the four operators and hex/scientific
literal boundaries. The latter previously bypassed pending double-character
operators. Three additional universal laws preserve left-error priority,
right-error propagation, and eager false-AND error handling. The proof book
contains 45 laws and the concrete suite 175 fixtures. Mutable String/Array
left-shift overloads remain incomplete; the bitwise family is not marked
complete. Both Bend 2.0.16 and 2.0.39 pass all 1,462 differential cases and the
full supporting checks. The 2.0.16 corpus run completed as one program;
`make parity-check` now checks all cases in ordered batches of 256, avoiding
the earlier run's greater-than-8-GB checker peak. The new runner also passes on
2.0.39. All 45 laws also pass its Lean-backed kernel verification. Native
verification of this checkpoint remains in progress; no GPU results or
performance measurements are claimed.
