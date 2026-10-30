# formula.bend

A formula evaluation library in Bend 2, reimplementing the Ruby
[Dentaku](https://github.com/rubysolo/dentaku) library. Excel and Google Sheets
formula compatibility, including mixed reference styles, are additional goals.

Early development. This is not yet a replacement for Dentaku, Excel, or Sheets.

## Current implementation

- Typed expression trees with natural-number literals, addition, multiplication,
  Boolean conditions, and explicit failures.
- Parallel evaluation of independent arithmetic operands. Conditional branches
  are lazy; only the selected branch is evaluated.
- A reference model with independent row and column anchors and forward copying.
- Five universal laws checked by Bend: literal preservation, both Boolean branch
  selections, absolute-axis preservation, and mixed row-anchor copying.

There is no formula string parser yet. Natural numbers are a temporary numeric
model; native Bend Nat is bounded and is not Ruby Integer or BigDecimal.
No GPU speedup or complete platform compatibility has been measured.

## Run

With Bend 2.0.16 (the version currently tested):

```sh
bend guide
bend PROOF.bend
bend examples.bend
# 42
bend examples.bend -o example
./example
```

The first two runs above check proofs and execute through Bend's JavaScript
backend respectively. Native, CUDA, and Metal execution still need verification.
The parallel call syntax in the engine exposes independent arithmetic work to
Bend's scheduler; the JavaScript backend executes sequentially.

## Compatibility work

See [COMPATIBILITY.md](COMPATIBILITY.md) for the baseline and remaining work.
The compiler project will live separately as `nelua-bend`. Bend is the initial
engine implementation; the planned authoring languages are Nelua/Lua, with Imba
for web interfaces.
