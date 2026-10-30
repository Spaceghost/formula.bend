# formula.bend

A formula evaluation library in Bend 2, reimplementing the Ruby
[Dentaku](https://github.com/rubysolo/dentaku) library. Excel and Google Sheets
formula compatibility, including mixed reference styles, are additional goals.

Early development. This is not yet a replacement for Dentaku, Excel, or Sheets.

## Current implementation

Formula strings support signed integer and decimal literals, ASCII identifiers,
Boolean literals, addition, subtraction, multiplication, whitespace, parentheses, and nested
`SUM`, `IF`, `NOT`, `ROUND`, `ROUNDUP`, and `ROUNDDOWN` calls. Multiplication has higher precedence than addition.
`SUM` builds a balanced addition tree; `IF` evaluates only the selected branch.
Functions are case-insensitive. Malformed expressions return explicit errors.

Bindings support case-insensitive matching by default, an explicit case-sensitive
mode, and first-match precedence for transient contexts. The reference model has
independent row and column anchors and supports forward copying.

Signed integer and decimal addition, subtraction, and multiplication use exact base-10 digit lists.
Small integers use a compact Nat representation; larger parsed integers stay in
digit lists. Coefficients can grow beyond a machine word. Decimal scale uses Nat.
Formatting preserves fractional zeros: `1.25 * .4` displays `0.500`.
This formatting is not a claim of Ruby BigDecimal display compatibility.

Nine universal laws and sixty-six concrete regression fixtures cover these
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

Division, exponent notation, comparisons,
strings, arrays, most built-ins, spreadsheet reference parsing, dependency
analysis, and the complete Dentaku Calculator API remain unimplemented.
`IF` and `NOT` accept Boolean conditions, not the full Ruby truthiness model.
The numeric representation is not yet a complete BigDecimal implementation.
The low-level Nat conversion helpers are intended for small values; callers
constructing large coefficients should use digit lists directly.

The reference model does not yet parse A1/R1C1 or support backward copying.
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
