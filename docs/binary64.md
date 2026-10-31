# Binary64 arithmetic foundation

`src/binary64.bend` implements a portable arithmetic layer for Ruby Float work.
It does **not** yet add Float bindings or Float results to the formula evaluator.
The existing formula corpus and this arithmetic corpus measure separate scopes.

The API provides word encoding, classification, sign inversion, addition,
subtraction, multiplication, division and ordered comparison. Operands enter as
two unsigned 32-bit words in IEEE binary64 order. Finite results, infinities and
signed zeros are compared word for word with Ruby 3.3.13. Arithmetic NaNs use a
canonical quiet NaN; their sign and payload are excluded from arithmetic value
comparisons. A separate word-encoding probe checks that input NaN payloads and
signs survive raw transport.

All arithmetic uses exact unsigned bit lists. A finite input is its significand
times `2^shift * 2^-1074`. Addition aligns exact magnitudes; multiplication
multiplies the compact significands before shifting; division retains an exact
remainder. The result is rounded once to nearest, with ties to an even final
significand. Guard and sticky bits cover discarded digits, including gradual
underflow and rounding across the subnormal/normal boundary. Cancellation and
underflow retain the required zero sign. No host Float, F32 approximation or
fused floating-point operation supplies an arithmetic result.

The implementation does not expose floating-point exception flags or alternative
rounding modes. An [exact decimal bridge](binary64-decimal.md) supplies IEEE
nearest/even conversion and signed exact projection. Ruby-compatible decimal
parsing, square roots, powers, transcendental functions,
Integer/BigDecimal coercion, evaluator result guards and
formula-level error propagation remain required work. This is not a claim of
complete IEEE 754 or Ruby Float support.

The [standalone Ruby Float formatter](binary64-format.md) supplies shortest
decimal output and Ruby notation rules without adding evaluator Float values.

## Verification

```sh
make binary64-check
```

Lua generates 4,595 deterministic probes: 27 named boundary/special values,
their Cartesian arithmetic/comparison matrix, 128 seeded random operand pairs,
and word/finite-value round trips. The seed is `0x6d2b79f5`. Inputs use raw words
to avoid lossy fixture conversion. Goldens are in `compat/binary64-oracle.tsv`.
The reference runner is `tools/run-binary64-oracle.lua`; it runs Ruby Float
operations directly, independently of the Bend arithmetic.

The same target also runs 441 separate exact-decimal conversion probes. Their
IEEE expectations use exact rational rounding intervals; observed Ruby parser
differences remain explicit compatibility gaps in the conversion profile.

The harness builds a balanced tree of independent checks before entering the
Bend bang and emits results in source order afterward. Input line construction
uses a tail-recursive traversal, including for large corpora. Its argument
handling supports Bend 2.0.16, which omits argv[0], and 2.0.39, which includes it.

Four additional laws cover sign inversion, signed-zero comparison, infinity
classification and unordered comparison with a NaN. They supplement the
differential tests; they do not prove the complete rounding algorithm.

Reference semantics:

- [Ruby 3.3 Float](https://docs.ruby-lang.org/en/3.3/Float.html) describes Ruby's
  native double representation and its numeric operations.
- [Berkeley SoftFloat interface](https://www.jhauser.us/arithmetic/SoftFloat-3/doc/SoftFloat.html)
  documents software binary64 arithmetic and nearest/even rounding terminology.
  This module uses its own exact bit-list implementation, not SoftFloat's C code.

At source `ab757f8`, all 4,595 probes pass Bun output from Bend 2.0.16 and 2.0.39,
clang 19.1.1 native CPU execution with one and eight threads, and required CUDA
execution on the Quadro P4000 with CUDA/NVRTC 12.9 and the default compilation
profile. There is no fallback, Metal result or performance comparison. The
initial padding/count traversal and curried division continuation exceeded the
2,048-word device stack; tail traversals and explicit division state fixed those
failures without changing the goldens or increasing that stack. Exact source,
input, shader and output hashes are in `../compat/backend-verification.json`.
