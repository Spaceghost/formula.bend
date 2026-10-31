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

The Lua-driven corpus has 5279 cases matched against Ruby values, parse
error classification, or exception-factory descriptions. It covers truthiness, strings/null, comparisons, selected
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
full runtime error-class/message parity remains unfinished. The 5279-case value and dependency
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
At that checkpoint CUDA and Metal were unverified; this is not a performance shootout.

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

Lookup generation groups 32 property ranges or eight mapping entries behind
balanced dispatch. Boolean mapping columns keep the older Bend checker from
expanding large numeric pattern refinements; each branch constructs only its
selected string. The resulting source has 828 functions, down from 4,417, with
the same reference table and ASCII fast paths. This reduces generated dispatch
without changing identifier or case-mapping rules.
With Bend 2.0.39, the runtime-loaded checker emits 6,281,383 bytes of C,
down from 7,940,117 bytes. This is a generated-code size measurement, not a
runtime performance result.
Both Bend 2.0.16 and 2.0.39 pass the full 2,516-case gate with this layout.
The 6,351 Unicode probes, Bun wire checks and Lean-backed proof gate pass as
well. Native clang 19.1.1 at `-O3` passes the same corpus and seven scale cases
with one and eight threads, plus all 14 malformed wire inputs. Artifact hashes
are recorded separately in `backend-verification.json`; formula CUDA execution
remains unverified.

`make unicode-boundary-check BUN=/path/to/bun` compares 6,351 probes against the
pinned table: every ASCII character, every lowercase/fold mapping key and its
adjacent scalars, and every alpha/word range boundary and adjacent scalars.
The check loads probes at runtime and compares all four lookup results. It
checks the generator against the pinned data; it does not rerun Ruby's Unicode
implementation. Table provenance remains the separate reference-runtime gate.

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
verification of this checkpoint also passes: all 1,462 cases and seven scale
checks match at `-O3` with one and eight threads. Source and artifact hashes are
recorded in `backend-verification.json`. No GPU parity results or performance
measurements are claimed.

## Dependency ordering and cycle groups

`src/resolver.bend` implements dependency ordering and ordered strongly connected
components. Its 1,054 differential checks cover all 512 directed three-node
graphs, with both ordering and cycle queries, plus the four upstream resolver
scenarios and named edge cases. All four source scenarios are mapped; the
correspondence map now contains 124 entries.

Normalization preserves first insertion order and the last original key and
dependency list for duplicate normalized names. Known keys retain their original
string or symbol type and spelling in resolve order; missing dependency nodes
use normalized string names. Case-sensitive mode keeps differently cased names
distinct. Cycle queries return normalized names in the source's component and
member order. A self-loop is reported by the cycle query but accepted by the
pinned Ruby topological-sort API. Multi-node cycles return TSort::Cyclic.

A depth-first traversal preserves discovery and finish order. Its structural
depth comes from the graph's exact vertex count plus one step for a closing
edge, including dependency names without keys. It has no configurable cutoff.
Dependency DAGs use this traversal directly. When a back edge exists, finite
Floyd–Warshall closure recovers component membership without recursive cycles.
Three additional laws preserve empty orders, empty cycles, and original key
values, bringing the proof book to 48 laws. The graph adapter currently accepts
ordered hashes of array dependency lists; malformed graph inputs and arbitrary
Ruby duck-typed objects do not yet have compatible diagnostics.
Both Bend 2.0.16 and 2.0.39 pass the full 2,516-case checks, all 48 laws, and
175 concrete fixtures. All 48 laws also pass its Lean-backed kernel check,
including the imported resolver implementation. All 2,516 cases and seven
scale checks also pass native CPU at `-O3` with one and eight threads.

## Linux CUDA toolchain check

The standalone `compat/cuda-toolchain-smoke.bend` check builds with Bend 2.0.39,
clang 19.1.1 and CUDA 13.0.88. Its 16,384-leaf fork computes 16,384 on both the
CPU pool and an RTX 3070 in required GPU mode, with a 1-GB GPU heap and driver
615.78.08. An explicit GPU size makes initialization failure an error instead
of allowing CPU fallback. `tools/run-cuda-smoke.lua` reproduces that check from
a frozen worktree using the existing development container and an external
CUDA toolkit. Toolkit archives were checked against NVIDIA's redistribution
manifest. Source, binary and GPU artifact hashes are recorded separately from
formula correctness evidence. This is a compiler/runtime smoke check; it
supplies no formula parity evidence or performance comparison by itself.

## Runtime-loaded correctness harness

The corpus can now be loaded as data by `compat/corpus-runtime.bend`. A balanced
fork tree runs each complete check inside one GPU call; file input and ordered
printing run on the host. Evaluation, parsing, dependencies, coercion, resolver
queries, and snapshot generation share the same operation dispatcher. The
executable and shader do not depend on fixture values, so adding cases does not
require a separate program or shader for each batch.

`tools/generate-wire.lua` preserves Integer/BigDecimal identity, negative decimal
zero, ordered hashes, symbol keys, original binding order, Unicode, and embedded
controls. Text lengths count codepoints. The decoder consumes the input
structurally and checks declared lengths against its actual size. Invalid
containers, truncated input, bad scalar types, malformed rows and unknown
operations fail before any result is emitted. Fourteen rejection cases pass on
both native CPU and JavaScript/Bun. All 2,516 reference cases and seven scale
checks pass through this transport on Bun 1.3.1 and native CPU with one and
eight threads at `-O3`.

`make wire-check` runs the JavaScript transport gate; provide `BUN=/path/to/bun`
when it is not on PATH. Bend 2.0.39's JavaScript File.read effect uses bun:ffi,
so this file-input harness requires Bun. The pinned 1.3.1 archive was checked
against its [official release digest](https://github.com/oven-sh/bun/releases/tag/bun-v1.3.1). Runtime and artifact hashes are separate
from the earlier generated-program checkpoints.

`tools/run-cuda-corpus.lua FROZEN_WORKTREE BEND_PACKAGE CUDA_TOOLKIT SCRATCH`
builds one native executable and shader, checks both CPU pool sizes, and checks
the shared corpus and scale inputs in required CUDA mode. Default-profile CUDA
correctness is still unverified: the default NVRTC builds have a long
optimization phase. The optional `tools/configure-cuda.lua` changes only the
generated host invocation to request a labeled --Ofast-compile profile, retaining
the existing --fmad=false setting and device implementation. [NVIDIA documents this](https://docs.nvidia.com/cuda/archive/13.0.2/nvrtc/index.html#supported-compile-options) as
a compile-time/runtime optimization tradeoff, so it must be recorded separately
from the default profile. No performance comparison is claimed.

The frozen `29854e6` interpreter now passes all 2,516 differential cases and
seven scale checks in required CUDA mode on a Quadro P4000, with a 1-GB GPU
heap, CUDA 12.9.86 and driver 580.178.04. This pass explicitly uses
`--Ofast-compile=max`; it is separate from the still-unverified default profile.
Both CPU pool sizes pass before the GPU checks. GPU outputs match the exact
reference files, and source/executable/shader/output hashes are recorded in
`backend-verification.json`. The generated runtime uses `cuLaunchKernel` for
the GPU bang and treats launch or synchronization failure as an error.

This result predates the later exception and decimal-transport changes. It
does not establish CUDA parity for the current corpus, Metal correctness, or
any performance ranking. The full source is embedded with `#embed __FILE__`;
the host-option edit changes those embedded bytes, while leaving the device
implementation unchanged. Keep every profile's shader artifact separate.

## Exception descriptions and factories

The separate `src/errors.bend` factories and generic `src/error_types.bend`
record preserve class relationships, reason, original metadata, constructor
attributes, message and `assigned_to`. All valid ParseError, TokenizerError and
ArgumentError reasons are covered, including missing fields and invalid
non-symbol reasons. Invalid reasons produce native ArgumentError descriptions;
Dentaku::ArgumentError and Dentaku::ZeroDivisionError retain their respective
Ruby standard-library relationships and the shared Dentaku error relationship.

131 differential cases compare complete snapshots with the pinned Ruby
factories. They cover UnboundVariableError, MathDomainError, NodeError,
ParseError, TokenizerError, ArgumentError, ZeroDivisionError and BaseError.
NodeError uses Ruby's Array conversion for the supported values, including nil
and ordered hashes. ParseError handles incompatible expectations and recursive
Array joining. Explicit nil message replacement returns the class name, while
text replacements preserve the payload. Assignment and replacement return new
Bend descriptions. Four universal laws preserve message replacement,
attributes, metadata, and assignment behavior, bringing the proof book to 52.
The complete JavaScript corpus now has 2,647 cases and the source scenario map
has 134 correspondences; the Ruby reference still has 713 examples.

This is factory parity for supported typed values, not complete exception
propagation. The evaluator's string failures have not yet been replaced by
structured descriptions. Metadata accepts the existing ordered hashes and
value types. At this factory-only checkpoint, Ruby Class/Float/Range values,
including open-ended arity ranges, were unsupported. Named class references
are added by the later checkpoint below; Float and Range remain open.
The new operation is available in both generated and runtime-loaded corpus
checkers; it is a test adapter, not additional formula syntax. Native and GPU
checkpoints remain tied to their recorded source revision and case count.

Reason names are looked up once into a shared enum; each factory formats only
its own reason group. Forty additional Ruby checks reject every valid reason
passed to either of the other two factories. This preserves the separate
whitelists without nested character-pattern dispatch. The runtime checker C
shrinks from 8,089,118 to 6,758,889 bytes (16.4%). This is generated-code size,
not a runtime timing result. All 131 factory cases pass both Bend versions;
all 2,647 cases and seven scale cases pass Bun and native CPU at `-O3` with
one and eight threads. Both transports reject all 14 malformed inputs.

## Typed decimal fixture transport

Typed BigDecimal fixture values preserve their sign across exterior ASCII
whitespace, including integer-looking negative zero. A single leading plus is
accepted. The static fixture generator and runtime decoder normalize these
inputs before converting the magnitude to a decimal and applying its sign.
The original text remains in the Ruby reference payload. Formula string
coercion keeps its existing whitespace rules.

Ten reference cases cover negative and positive zero, signed nonzero values,
scientific notation, spaces, tabs, newlines, carriage returns, vertical tabs
and form feeds. Three transport laws preserve both zero signs and reject a
second sign. The wire rejection corpus now has 18 cases, including all four
doubled-sign combinations.
All 2,526 cases pass on both Bend 2.0.16 and 2.0.39. The 51-law gate passes
Lean-backed checking on Bend 2.0.39. Bun 1.3.1 and native clang 19.1.1 at `-O3`
pass the full runtime-loaded corpus, seven scale checks and 18 malformed inputs;
the native checks pass with both one and eight threads. The typed decimal
checkpoint records exact artifact and input hashes in `backend-verification.json`.
The merged checkpoint at `c22a813` combines exception dispatch and typed decimal
transport: 2,657 cases, 55 laws, seven scale checks and 18 malformed inputs.
Bun and native CPU pass the complete runtime-loaded corpus; native checks use
one and eight threads at `-O3`. Bend 2.0.16 reuses the byte-identical 2,304-case
prefix from its verified transport checkpoint and executes both changed
batches, covering all 353 remaining cases. Existing source modules were checked
for changes before reuse, and every retained output matches the merged golden.
The prefix artifact hashes and all checkpoint hashes are recorded in the repo.

## Typed integer fixture imports

Fixture `{integer='...'}` inputs use Ruby's `Integer(String)` rules with an
inferred base. The static and wire encoders share a Lua normalizer for binary,
octal, decimal and hexadecimal prefixes, leading-zero octal, one sign, digit
separators and exterior ASCII whitespace. Nondecimal magnitudes are converted
to decimal digits without putting the complete value in a Lua number. Ruby
reference payloads retain their original strings.

Twenty formula cases exercise these imports through CONCAT, including values
larger than 64 bits. A separate pinned Ruby 3.3.13 profile checks 5,326 strings:
1,768 accepted and 3,558 rejected. These are fixture-converter checks, counted
separately from formula parity. `make integer-context-check` validates the
profile; `tools/run-integer-reference.lua STORAGE RUNROOT OUTPUT` regenerates
it in the pinned Ruby reference container. Formula numeric-literal grammar is
unchanged by this fixture transport normalization.
The integer-import checkpoint adds 20 formula cases for a total of 2,677.
All 20 run on both Bend 2.0.16 and 2.0.39; the full corpus and seven scale
cases pass Bun and native CPU with one and eight threads. The existing native
and JS executables are reused only after checking that their Bend source is
unchanged. The 55-law Lean-backed gate passes as well. This adds no new claim
about GPU execution of these imports or about complete Ruby numeric classes.

## Named class and module values

`Core.NamedReference` carries a class/module kind, canonical name and ordered
ancestor names. Typed bindings use `{class='...', ancestors={...}}` or
`{module='...', ancestors={...}}`. The caller supplies the owning runtime's
complete ancestor list, excluding the reference itself; the engine does not
resolve Ruby constants. The reference adapter validates every descriptor against
the actual pinned Ruby object. The probes load JSON as the oracle does, because
its included modules can affect those ancestor lists.

The new values preserve rendering, identity, truthiness, value classes, hash
keys and array-set behavior. Subtype comparisons include class/module mixins
and return nil for unrelated references. Mixed comparison failures distinguish
missing operators, scalar comparison failures, Hash conversion failures and
comparisons against non-class/module operands. Exception metadata now retains
actual named classes, including Dentaku::AST::Addition and Numeric, rather than
using display strings in their place. Three further exception examples have
exact source correspondences.

The 2,602 additional Ruby comparisons include a complete six-operator matrix
for 19 named references, mixed scalar comparisons, hash keys and exact exception
payloads. The integrated corpus has 5,279 cases, 60 laws, 175 concrete fixtures
and 137 source scenario correspondences. Its full checks run on both Bend
versions; Bun and native CPU check the full runtime-loaded corpus plus seven
scale cases. Native checks use one and eight threads at `-O3`. Both transports
reject 23 malformed inputs, including invalid named-reference framing.

Named references remain immutable descriptors. Ruby class execution,
reflection, anonymous objects and namespace mutation are not implemented.
Range and Float values, full structured evaluator failures, and broader
calculator/function-registry behavior remain open. The recorded CUDA pass
continues to cover only the earlier 2,516-case source checkpoint.

## Integer Range conversion in exception construction

Finite integer-start ranges enumerate expected operand values for `NodeError`
and `ParseError`'s `node_invalid` reason. Integer endpoints remain exact even
when they exceed a machine word, provided the materialized span fits the runtime
Nat representation. Exclusive, descending, negative and mixed integer/decimal
end bounds follow the reference checks. Endless ranges produce Ruby's native
`RangeError`; beginless and non-iterable ranges produce `TypeError` with their
class-specific messages. A parse error without an operation skips conversion,
preserving the reference's lazy message branch.

The 51 added Ruby-oracle checks cover these constructor paths and their complete
snapshots. String and Symbol successor enumeration, Range hash keys, Float
endpoints and arbitrary Ruby object iteration remain unfinished.
