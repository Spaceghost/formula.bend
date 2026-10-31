# Float values and Ruby numeric dispatch

Formula bindings can carry binary64 values through `Core.float_words(high, low)`.
Fixture data uses `{float_words={high, low}}`; each word is an unsigned 32-bit
integer. The static and file-input paths validate the descriptor independently.
Float snapshots use raw words, with NaNs compared by classification. Display
uses the standalone Ruby Float formatter. Decimal formula literals continue to
produce BigDecimal values, as in the pinned Dentaku reference.

Arithmetic and comparison preserve numeric classes. Integer/Float arithmetic
promotes the Integer to binary64; comparison uses the exact Integer instead of
rounding it first. Mixed BigDecimal arithmetic uses the pinned implicit Float
coercion. Division and modulo convert the right Float through its shortest text
and the left Float through implicit coercion. Non-finite BigDecimal results have
an explicit representation. Typed decimal bindings admit `Infinity`, `-Infinity`
and `NaN` without changing ordinary formula tokenization.

Finite operands producing a non-finite result in addition or multiplication
produce a Dentaku argument error. `SUM` and `MUL` follow the reference's direct
Ruby reductions, which allow infinity. Float reductions run in source order;
argument evaluation remains balanced and independent. Exact reductions retain
their balanced implementation. NaN extrema and invalid integer conversions
preserve their native exception class and message through `Core.Raised`.
Non-bang evaluation preserves native errors instead of silently returning null.

`ROUND` follows Ruby's binary half-step correction for small positive precisions
and its rational path for larger precisions. The rational conversion models the
pinned 64-bit Ruby integer division, including leading-limb truncation and the
separate quotient/`ldexp` rounding steps. `ROUNDUP` and `ROUNDDOWN` use shortest
decimal conversion followed by BigDecimal rounding and conversion back to Float.
Nonpositive precisions produce Integer results; positive precisions preserve
Float or BigDecimal input class. Precision validation retains native errors.

The dedicated Float corpus covers raw bindings, signed zero, normal/subnormal
values, infinities/NaNs, arithmetic, coercion, comparison, numeric reductions,
rounding, large Integer comparisons, native errors, and exact upstream rounding
regressions with result-class checks. It is a verified subset of Dentaku parity,
not a replacement for the full upstream scenario inventory. The former COUNT
fixture adaptation now uses actual Float bindings.

Float Array/String indices truncate toward zero and enforce Ruby’s signed
64-bit long range. Range failures retain the original Float rendered with Ruby’s
10-significant-digit error profile. Shift counts accept finite Floats and
truncate toward zero; bitwise AND/OR still reject Float operands. Array repetition
translates index-conversion errors into Dentaku argument errors. The separate
450-case Float access corpus checks values and error messages at signed-long
boundaries, infinities, signed zeros and NaNs.

Full Ruby object identity for Float values, numeric Hash keys, global BigDecimal
modes, remaining built-ins and complete Calculator coverage remain unfinished.
The reference profile is Ruby 3.3.13 / BigDecimal 3.1.5 on 64-bit Linux. Foundation
target results do not by themselves verify this larger evaluator runtime; its
native CPU/GPU checks are recorded separately in backend verification metadata.
