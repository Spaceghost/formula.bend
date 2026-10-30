# formula.bend

A formula evaluation library in Bend 2, reimplementing the Ruby
[Dentaku](https://github.com/rubysolo/dentaku) library. Excel and Google Sheets
formula compatibility, including mixed reference styles, are additional goals.

Early development. This is not yet a replacement for Dentaku, Excel, or Sheets.

## Current implementation

Formula strings support signed integer and decimal literals, ASCII identifiers,
Boolean literals, addition, subtraction, multiplication, division, whitespace, parentheses, and nested
`SUM`, `IF`, `NOT`, `ROUND`, `ROUNDUP`, and `ROUNDDOWN` calls. Multiplication has higher precedence than addition.
`SUM` builds a balanced addition tree; `IF` evaluates only the selected branch.
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

Thirteen universal laws and one hundred twelve concrete regression fixtures cover these
parts. They do not establish full Ruby or spreadsheet compatibility.

## Example

```python
import Base
import ./src/core.bend as Core
import ./src/parser.bend as Parser

def main() -> String:
  Core.show(Parser.evaluate("SUM(kiwi, 0.1, 0.2)", [Core.Bound{"kiwi", Core.Number{2n}}], False{}))
# "2.3"
```

## Verify

With Bend 2.0.16 (the version currently tested):

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

Exponent notation, logical operators,
arrays, most built-ins, spreadsheet formula lookup, dependency
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
work. The compiler project will live separately as `nelua-bend`. Bend is the
initial engine; the planned authoring languages are Nelua/Lua, with Imba for web
interfaces.

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
A separate 31-case scalar corpus currently matches Ruby on selected values and
parse-error classification. `make parity-check` generates the fixtures using Lua.
Use `LUA=/path/to/lua` if Lua is not on PATH.

The parser now supports `=`, `==`, `!=`, `<>`, `<`, `<=`, `>`, and `>=`, with
arithmetic taking precedence. String and null literals, Ruby truthiness, and
selected decimal numeric-string coercions are implemented. A static pass rejects
invalid arithmetic operand types before evaluation, including unused branches.
See [the parity checklist](compat/PARITY.md) for remaining rules and the shootout
gate. No performance comparison is claimed yet.
