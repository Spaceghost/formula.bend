# formula.bend

A formula evaluation library in Bend 2, reimplementing the Ruby
[Dentaku](https://github.com/rubysolo/dentaku) library. Excel and Google Sheets
formula compatibility, including mixed reference styles, are additional goals.

Early development. This is not yet a replacement for Dentaku, Excel, or Sheets.

## Current implementation

Formula strings support signed integer, decimal, scientific, and hexadecimal literals, ASCII identifiers,
Boolean literals, addition, subtraction, multiplication, division, whitespace,
parentheses, and nested calls. Numeric functions include `SUM`, `MUL`, `MIN`,
`MAX`, `AVG`, and `ABS`; logical functions include `IF`, `NOT`, `AND`, `OR`, and
`XOR`; rounding functions are `ROUND`, `ROUNDUP`, and `ROUNDDOWN`.
Arrays support nesting, concatenation, subtraction, repetition, and equality.
Postfix indexing supports arrays and strings, negative indexes, and null-safe
value evaluation. `COUNT` follows Dentaku's distinct single/multiple argument rules.
String functions include `LEFT`, `RIGHT`, `MID`, `LEN`, `FIND`, `SUBSTITUTE`,
`CONCAT`, and `CONTAINS`. `SWITCH` uses its first matching key or a default.
`CASE … WHEN … THEN … ELSE … END` supports nested cases and lazy branches.
Function arguments and numeric reductions use balanced trees. `IF` evaluates
only the selected branch; logical function calls retain eager argument rules.
Functions are case-insensitive. Malformed expressions return explicit errors.

Bindings support case-insensitive matching by default, an explicit case-sensitive
mode, and first-match precedence for transient contexts.

Persistent Calculator state supports normalized memory, optional nested-data
flattening, temporary contexts, bulk array/hash evaluation and a typed AST
cache. Cache keys preserve scalar input types; prewarmed entries are read even
when new writes are disabled. See [the Calculator contract](docs/calculator-api.md).
Stored formulas, aliases, custom functions, error-handler blocks and full
Calculator parity remain unfinished.

The standalone address layer parses and renders A1 and R1C1, retains independent
row/column anchors, and supports copying in either direction with bounds checks.

Signed integer and decimal addition, subtraction, and multiplication use exact base-10 digit lists.
Small integers use a compact Nat representation; larger parsed integers stay in
digit lists. Coefficients can grow beyond a machine word. Decimal scale uses Nat.
Formatting preserves fractional zeros: `1.25 * .4` displays `0.500`.
This formatting is not a claim of Ruby BigDecimal display compatibility.

Standalone binary64 layers provide arithmetic, exact decimal conversion,
[Ruby Float formatting](docs/binary64-format.md),
[pinned BigDecimal-to-Float conversion](docs/binary64-ruby-decimal.md), and
[Float-to-BigDecimal coercion profiles](docs/binary64-bigdecimal.md).
Formula bindings now carry typed Float values, with mixed numeric dispatch and
native errors. See [Float evaluator behavior and limits](docs/float-values.md).
The independent foundation probes and formula corpus measure separate scopes.

Universal laws and concrete regression fixtures cover these
parts. They do not establish full Ruby or spreadsheet compatibility.

## Example

```bend
import Base
import ./src/core.bend as Core
import ./src/parser.bend as Parser

def main() -> String:
  Core.show(Parser.evaluate("SUM(kiwi, 0.1, 0.2)", [Core.Bound{"kiwi", Core.Number{2n}}], False{}))
# "2.3"
```

## Verify

The current evaluator requires Bend 2.0.39. Historical checkpoints and the
standalone numerical corpus also cover Bend 2.0.16. That older compiler rejects
the current mutually recursive stored-AST/value types:

```sh
bend guide
make check
make native-check
```

`make check` checks all laws and regression fixtures, then compares JavaScript
execution with expected output. `make native-check` needs a compatible clang and
compares the native program with the same output. Build outputs stay in `build/`.
All nineteen arithmetic/function runtime cases and eight rounding runtime cases
have passed on JavaScript and native CPU. A frozen 2,516-case interpreter
checkpoint and seven scale cases also pass CUDA on a Quadro P4000 with the
explicit `--Ofast-compile=max` profile. Default-profile CUDA, newer interpreter
changes, and Metal remain unverified. No performance comparison is claimed.

## Compatibility limits

Most built-ins, spreadsheet formula lookup, complete stored-formula integration
and the complete Dentaku Calculator API remain unfinished.
`IF` and `NOT` follow Ruby truthiness: only false and null are falsey.
The numeric representation is not yet a complete BigDecimal implementation.
The low-level Nat conversion helpers are intended for small values; callers
constructing large coefficients should use digit lists directly.

The standalone address layer parses A1 and R1C1, supports mixed anchors and signed
offsets, renders both styles, and checks resolution against caller-provided sheet
bounds. Formula lookup, ranges, and sheet-qualified addresses are still pending.
The JavaScript backend executes sequentially. The engine exposes independent
arithmetic calls to Bend's native scheduler; useful parallel batch execution
remains to be developed and benchmarked.

See [COMPATIBILITY.md](COMPATIBILITY.md) for the complete baseline and remaining
work. The engine uses Bend 2 and development tooling uses Lua.

Rounding currently follows Ruby Dentaku: `ROUND` uses half-away-from-zero,
`ROUNDUP` is ceiling, and `ROUNDDOWN` is floor. Negative decimal places are
supported. These last two functions differ from Excel for negative inputs;
Excel and Sheets profiles are still pending. See the rounding profile in
COMPATIBILITY.md for precision limits. The eight rounding runtime cases pass on
JavaScript and native CPU.

Division uses an operand-dependent precision profile matching the recorded Ruby
3.3.13 / BigDecimal 3.1.5 reference. Seven differential cases cover terminating
and repeating quotients, large integers, and tiny decimals. `Core.divide_at`
also accepts explicit fractional places and rounding. Division by zero returns
an explicit error. Other BigDecimal versions and global rounding modes are not
yet compatibility profiles. See [the reference corpus](compat/README.md).
The seven division reference cases pass on both JavaScript and native CPU.

Address examples: `$A1` copied from B2 to D5 becomes `$A4`; `R[-1]C[2]` at F6
resolves to H5. The address layer is tested separately from formula evaluation.
The eight address runtime cases pass on both JavaScript and native CPU.

## Dentaku parity work

Parity is measured against the pinned Ruby source and its complete 713-example
suite. The Ruby reference passes all examples; that is not a claim that Bend does.
A separate 10863-case corpus covers selected values,
dependencies, parse-error classification, and exception factories.
`make parity-check` generates the fixtures using Lua.
Use `LUA=/path/to/lua` if Lua is not on PATH.

The parser now supports `=`, `==`, `!=`, `<>`, `<`, `<=`, `>`, and `>=`, with
arithmetic taking precedence. String and null literals, Ruby truthiness, and
selected decimal numeric-string coercions are implemented. A static pass rejects
invalid arithmetic operand types before evaluation, including unused branches.
See [the parity checklist](compat/PARITY.md) for remaining rules and the shootout
gate. No performance comparison is claimed yet.

The corpus supports exact decimal, integer, raw-word Float, string, Boolean, null, nested array,
ordered hash, named class/module and Range bindings, plus case-sensitive contexts.
All 10,863 cases pass Bun, along with seven scale checks and 36 malformed-input
checks. All 117 laws pass Lean-backed verification on Bend 2.0.39. There are 158
upstream scenario mappings and 175 concrete regression fixtures. The preceding 10,413-case checkpoint passed native CPU
with one and eight threads; the 450 new access probes await native replay.
GPU replay of this evaluator source remains pending.

An additional 283 probes cover stored AST values, formula-aware dependencies and
checked AST evaluation. They pass Bun on this source; their earlier checkpoint
also passed native CPU with one and eight threads.
The corpus includes a 257-formula chain, locally rebound recursion, branch
pruning, dependency-first errors and messages. The recursive runners remain
outside termination proofs. Calculator state/cache evaluation entry points are
not yet connected; see [stored expressions](docs/stored-expressions.md).

An earlier 8,798-case checkpoint passed full static replay and all concrete
fixtures on Bend 2.0.39; the expanded source awaits that complete static gate.
The checker launcher requests a 64 MiB process stack for large diagnostics;
FORMULA_CHECK_STACK_KIB overrides it within the host hard limit.
Historical source revisions and artifact hashes are recorded separately in
compat/backend-verification.json. Current-source CUDA and Metal remain
unverified; no performance result is claimed.

Typed token descriptors and matchers include counterparts of all 11 upstream
TokenMatcher examples. Both AST Node dependency examples are represented by
nine assertions, including guard pruning and empty input. These nine probes
also pass static replay on both Bend versions. See [the matcher contract](docs/token-matcher.md)
for immutable modifiers, Hash-key identity, compound inversion and negative
stream offsets. These APIs still need integration with the parser's lexer and
a token scanner; mutable aliases remain incomplete.

The separate 5,326-string Ruby Integer profile checks fixture conversion rather
than formula coverage.

Exception factories preserve reasons, metadata, constructor attributes, message
overrides and assignment values. Their differential cases cover every
factory reason and shared/stdlib error relationships. The Bend API uses
immutable descriptions. Evaluator errors still need integration with those
descriptions; Float metadata is not yet supported.

Range values retain inclusive/exclusive endpoints, Ruby rendering, truthiness,
comparisons and open-ended arity metadata. Integer-start ranges enumerate values
for exception constructor arguments using exact decimal blocks; endless and
non-iterable ranges preserve native conversion errors. String/Symbol successor
enumeration, Range hash keys and Float endpoints remain incomplete.

Named class and module values preserve their canonical names, kind and ancestor
names. They support identity, subtype comparisons, truthiness, hash keys and
class-valued exception metadata. Callers supply the complete ancestor list from
the owning runtime. These descriptors do not execute Ruby class methods or
represent anonymous objects.

Scientific exponents support at most 14 significant exponent digits; scales and
indexes remain bounded by the runtime Nat representation. Hex coefficients use
exact decimal digit lists. This is not complete Ruby numeric-class compatibility.

Integer and BigDecimal results now remain distinct across parsing, arithmetic,
division, aggregates, and rounding. The corpus checks result classes and direct
NumericParser coercions as well as canonical values. Signed decimal zero is
preserved through arithmetic, rounding, comparisons, indexing, and string
conversion. Float and non-finite numeric bindings are supported in the current
numeric profile. Global BigDecimal modes and full numeric-class parity remain
pending.

A separate [binary64 foundation](docs/binary64.md) passes 13,253 arithmetic,
conversion, formatting and coercion probes on both Bend versions' JavaScript
output, native CPU with one and eight threads, and required CUDA on the P4000
with default NVRTC options at source `0f0aa97`. These probes are separate from
the formula/API cases and do not establish full evaluator GPU parity.

The oracle also checks AST result types and selected exact error messages.
`make parity-check` validates the recorded upstream scenario mappings. New
batches can be added with `tools/extend-corpus.lua` after their Bend output
matches the Ruby oracle exactly. Regex values and complete Ruby String behavior
remain outside the current implementation.

Infix AND, OR, XOR, prefix NOT, and `!` follow the pinned Dentaku precedence and
static logical-operand rules. AND/OR short-circuit and allow a decisive right
operand to resolve an unbound left operand. Function AND/OR/XOR have their own
argument collection and type-validation rules.
Parser.identifiers reports unique syntactic inputs; Parser.dependencies prunes
resolvable IF/AND/OR branches. Public formula evaluation checks dependencies
before evaluating, while Core.evaluate_in remains direct AST evaluation. Stored
formula values, cycles, and volatile custom-function analysis are not implemented.
The labeled CUDA fast-compile checkpoint now covers all 2,677 pre-token cases
and seven scale cases on the P4000. The newer token API needs its own GPU
checkpoint; default-profile CUDA and Metal remain unverified.
