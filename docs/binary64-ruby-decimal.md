# Pinned Ruby BigDecimal-to-Float conversion

`RubyBinaryDecimal.from_decimal` models BigDecimal#to_f in the pinned Ruby
3.3.13 / BigDecimal 3.1.5 reference image with its default numeric settings.
It is separate from the exact IEEE converter in `binary64_decimal.bend`.
The evaluator selects this profile explicitly when a BigDecimal-to-Float path
requires the pinned Ruby behavior.

The BigDecimal implementation emits normalized `0.<digits>eN` text and passes
it to Ruby's bundled `strtod`. That parser's fractional-digit loop stops
accumulating once `nd > DBL_DIG * 4`, where `DBL_DIG` is fifteen. Pending zero
digits do not advance `nd` until a nonzero arrives. Consequently, the retained
prefix ends at the first nonzero digit after sixty significant digits. This is
occasionally longer than sixty-one digits; an arbitrary fixed-length cutoff
would model the parser incorrectly.

The Bend path normalizes the coefficient, locates this cutoff, discards the
remaining low decimal places without a sticky bit, restores their place value,
and rounds the retained exact quantity to binary64. Signed zero is preserved.
This intentionally reproduces the pinned BigDecimal path's rounding differences
at some binary midpoints. The IEEE path continues to retain the original tail
and round the original exact value.

The separate Ruby corpus includes all 279 decimal inputs from the IEEE bridge
corpus, plus 960 cases varying cutoff positions, delayed nonzero digits,
integer zeros, signs, normal/subnormal magnitudes and overflow. Expected words
come directly from BigDecimal#to_f. The existing discrepancy profile remains
useful evidence of the difference between Ruby and IEEE semantics.

This scope does not model Ruby Float(text) for arbitrary text layouts, global
BigDecimal exception/precision modes, or other Ruby/BigDecimal releases. The
bundled parser can behave differently when the same digits appear before the
decimal point; such calls must not be redirected to this normalized BigDecimal
conversion path. Broader numeric coercion and evaluator integration remain open.

Pinned sources:
[BigDecimal_to_f](https://github.com/ruby/bigdecimal/blob/v3.1.5/ext/bigdecimal/bigdecimal.c)
and [Ruby strtod](https://github.com/ruby/ruby/blob/v3_3_13/missing/dtoa.c).
