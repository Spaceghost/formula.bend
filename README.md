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

The standalone address layer parses and renders A1 and R1C1, retains independent
row/column anchors, and supports copying in either direction with bounds checks.

Signed integer and decimal addition, subtraction, and multiplication use exact base-10 digit lists.
Small integers use a compact Nat representation; larger parsed integers stay in
digit lists. Coefficients can grow beyond a machine word. Decimal scale uses Nat.
Formatting preserves fractional zeros: `1.25 * .4` displays `0.500`.
This formatting is not a claim of Ruby BigDecimal display compatibility.

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

Tested with Bend 2.0.16 and 2.0.39:

```sh
bend guide
make check
make native-check
```

`make check` checks all laws and regression fixtures, then compares JavaScript
execution with expected output. `make native-check` needs a compatible clang and
compares the native program with the same output. Build outputs stay in `build/`.
All nineteen arithmetic/function runtime cases and eight rounding runtime cases
have passed on JavaScript and native CPU. CUDA and Metal remain unverified.

## Compatibility limits

Most built-ins, spreadsheet formula lookup, stored-formula dependency
analysis, and the complete Dentaku Calculator API remain unimplemented.
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
A separate 2657-case corpus matches Ruby on JavaScript for selected values,
dependencies, parse-error classification, and exception factories.
`make parity-check` generates the fixtures using Lua.
Use `LUA=/path/to/lua` if Lua is not on PATH.

The parser now supports `=`, `==`, `!=`, `<>`, `<`, `<=`, `>`, and `>=`, with
arithmetic taking precedence. String and null literals, Ruby truthiness, and
selected decimal numeric-string coercions are implemented. A static pass rejects
invalid arithmetic operand types before evaluation, including unused branches.
See [the parity checklist](compat/PARITY.md) for remaining rules and the shootout
gate. No performance comparison is claimed yet.

The corpus supports exact decimal, integer, string, Boolean, null, and nested
array and ordered hash bindings plus case-sensitive contexts. MAP, FILTER, ALL, ANY, and REDUCE
also pass seven reference checks over 1,025-item collections. Both Bend 2.0.16
and 2.0.39 pass all 2,657 cases on JavaScript, with 55 laws and 175 concrete
fixtures. The checker runs the corpus in batches of 256 to bound peak memory.
All 55 laws pass Lean-backed kernel verification on Bend 2.0.39.
The 2,657-case checkpoint and seven scale
checks pass native CPU with one and eight threads at `-O3`.
Source commits and checksums are recorded in
`compat/backend-verification.json`.
The Bend 2.0.16 integration check reuses 2,304 source-identical passing cases
and executes the 353 cases in changed batches; the recorded hashes make that
reuse auditable.

Exception factories preserve reasons, metadata, constructor attributes, message
overrides and assignment values. Their 131 differential cases cover every
factory reason and shared/stdlib error relationships. The Bend API uses
immutable descriptions. Evaluator errors still need integration with those
descriptions; Float/Class/Range metadata is not yet supported.

Scientific exponents support at most 14 significant exponent digits; scales and
indexes remain bounded by the runtime Nat representation. Hex coefficients use
exact decimal digit lists. This is not complete Ruby numeric-class compatibility.

Integer and BigDecimal results now remain distinct across parsing, arithmetic,
division, aggregates, and rounding. The corpus checks result classes and direct
NumericParser coercions as well as canonical values. Signed decimal zero is
preserved through arithmetic, rounding, comparisons, indexing, and string
conversion. Ruby Float inputs, special numeric values, and global BigDecimal
modes remain pending.

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
