# formula.bend

A formula evaluation library in Bend 2, reimplementing the Ruby
[Dentaku](https://github.com/rubysolo/dentaku) library. Excel and Google Sheets
formula compatibility, including mixed reference styles, are additional goals.

Early development. This is not yet a replacement for Dentaku, Excel, or Sheets.

## Current implementation

Formula strings support natural-number literals, ASCII identifiers, Boolean
literals, addition, multiplication, whitespace, and parentheses. Multiplication
has higher precedence than addition. Malformed expressions return explicit parse
errors. Bindings support case-insensitive matching by default, an explicit
case-sensitive mode, and first-match precedence for transient contexts.

The typed AST also supports lazy Boolean conditions and explicit failures.
Independent arithmetic operands use parallel calls. References have independent
row and column anchors and support forward copying.

Six universal laws and twenty concrete regression fixtures cover these parts.
They do not establish full Ruby or spreadsheet compatibility.

## Example

```python
import Base
import ./src/core.bend as Core
import ./src/parser.bend as Parser

def main() -> Core.Value:
  Parser.evaluate("kiwi + 5 * 2", [Core.Bound{"kiwi", Core.Number{2n}}], False{})
# Number{12n}
```

## Verify

With Bend 2.0.16 (the version currently tested):

```sh
bend guide
make check
make native-check
```

`make check` checks all laws and regression fixtures, then compares JavaScript
execution with the expected output. `make native-check` needs a compatible clang
and compares the native program with the same output. Build outputs stay in
`build/`. The initial AST example has passed on JS and native CPU. CUDA and Metal
remain unverified. No GPU speedup has been measured.

## Compatibility limits

There are no decimal or negative numbers, subtraction, division, function-call
syntax, spreadsheet reference parsing, dependency analysis, or complete Dentaku
Calculator API yet. Natural numbers are a temporary numeric model; native Bend
Nat is bounded and is not Ruby Integer or BigDecimal. `IF` currently exists only
in the AST and accepts Boolean conditions, not the full Ruby truthiness model.

The reference model does not yet parse A1/R1C1 or support backward copying.
The JavaScript backend executes sequentially. The engine exposes independent
arithmetic calls to Bend's native scheduler; workload balancing and useful
parallel batch execution remain to be developed and benchmarked.

See [COMPATIBILITY.md](COMPATIBILITY.md) for the complete baseline and remaining
work. The compiler project will live separately as `nelua-bend`. Bend is the
initial engine; the planned authoring languages are Nelua/Lua, with Imba for web
interfaces.
