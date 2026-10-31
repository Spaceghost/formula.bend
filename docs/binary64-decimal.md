# Exact decimal and binary64 conversion

`src/binary64_decimal.bend` converts a finite exact decimal to binary64 using
nearest/even rounding, and projects a binary64 value to an exact signed decimal.
Non-finite projections use explicit infinity/NaN variants. Signed zero survives
both directions. This bridge does not yet expose Float values in the evaluator.

The exact projection removes powers of two from the significand before using
`m * 2^k` or `m * 5^k / 10^k`. Decimal conversion uses integer binary division
with an exact remainder. Cached divisor/remainder widths avoid repeatedly
scanning a long divisor before it can fit. Digit addition, small multiplication,
padding and input parsing use tail traversals to bound device stack use.

## Decimal tails and midpoint rounding

Every finite binary64 value is an integer multiple of `2^-1074`. Its rounding
midpoints therefore lie on the `2^-1075` grid, including the zero/subnormal edge;
the overflow midpoint lies on that grid too. Each midpoint has a terminating
decimal representation with at most 1,075 fractional places.

The converter can discard decimal fractional places beyond 1,075 while retaining
whether the discarded tail was nonzero. Such a tail cannot cross a binary
rounding midpoint unless the retained value is exactly at it; in that case the
sticky bit breaks the tie upward in magnitude. This bounds the arithmetic needed
after reading the input, while preserving decisions made by a digit thousands of
places beyond a midpoint. It is a mathematical precision bound, not a limit on
the number of source decimal digits.

The conversion corpus includes exact Float projections, round trips, signed
zeros, very large scales, subnormal/normal boundaries, overflow, integer rounding,
and decimal inputs with 10,000 extra digits below, at and above midpoints. Exact
rational comparisons with adjacent Float values validate the IEEE oracle; the
host libc parser supplies only an initial candidate. The algorithm is checked
differentially; the project's zero/infinity laws do not constitute a complete
proof of the rounding algorithm.

## Ruby parsing compatibility remains open

The pinned Ruby 3.3.13 / BigDecimal 3.1.5 reference image is musl-based. Its native
Float arithmetic and libc conversion agree with the exact IEEE midpoint tests,
but Ruby's bundled decimal parsing differs on some boundary inputs. The decimal
text's representation can also change that result. For example, just above half
the smallest subnormal, BigDecimal#to_f produces zero while IEEE conversion
produces the smallest subnormal. Some exact overflow midpoint inputs differ too.

`compat/binary64-conversion-ruby-profile.tsv` records all observed discrepancies
by fixture ID, with BigDecimal#to_f, Float(text), and exact IEEE results. They
remain incomplete Ruby compatibility items. `from_decimal` is explicitly the
IEEE conversion; it must not silently stand in for the pinned Ruby conversion
when the evaluator's coercion profile is added. Ruby-compatible conversion,
Float formatting and mixed numeric coercions remain required work.

References: [Ruby Float](https://docs.ruby-lang.org/en/3.3/Float.html#method-i-to_r),
[BigDecimal conversion](https://docs.ruby-lang.org/en/3.3/BigDecimal.html#method-i-to_f),
and the pinned [Ruby decimal parser source](https://github.com/ruby/ruby/blob/v3_3_13/missing/dtoa.c).
