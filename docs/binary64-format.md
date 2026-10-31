# Ruby Float formatting

`BinaryFormat.show` renders a raw binary64 value in the pinned Ruby 3.3.13
Float#to_s format. It preserves signed zero, renders infinities and NaNs, and
chooses the shortest decimal inside the value's exact rounding interval. The
standalone formatter does not yet add Float values to the formula evaluator.

The search starts with one significant decimal digit. At each precision it
checks both neighboring decimal candidates, preferring the nearer one and
breaking decimal ties with an even coefficient. Both candidates matter because
powers of two have asymmetric binary rounding intervals. Endpoint inclusion
depends on the binary significand's parity. Exact decimal sums describe twice
each interval boundary; the upper neighbor of the largest finite value is the
virtual exact value `2^1024`. This avoids rounding the boundaries themselves.
The search terminates at the exact decimal representation if necessary.

Notation follows Ruby's `flo_to_s` branch order. A positive decimal-point
position inside the significant digits uses fixed notation, including fractional
values around `10^15`. An integral value with more than fifteen integer places
uses scientific notation. Small values use fixed notation down through `10^-4`.
Scientific exponents carry a sign and at least two digits. A representation with
no fractional digits receives `.0`.

Lua generates 6,668 word-based probes: special values and notation thresholds,
every normal exponent bin and its immediate neighbors, and 512 seeded random
values. Ruby supplies the expected strings directly. The corpus checks decimal
digits and notation together; it does not use the new formatter as its oracle.
The zero, infinity and NaN laws supplement these comparisons without claiming
a complete proof of the shortest-decimal algorithm.

The reference implementation is pinned in
[Ruby's numeric.c](https://github.com/ruby/ruby/blob/v3_3_13/numeric.c)
(`flo_to_s`) and
[missing/dtoa.c](https://github.com/ruby/ruby/blob/v3_3_13/missing/dtoa.c)
(`dtoa`, mode zero). This module uses exact decimal arithmetic rather than a
port of the C implementation.
