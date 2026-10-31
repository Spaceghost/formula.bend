# Allocation-related numeric exceptions

A Calculator reference probe of `1 << 18446744073709551616` terminated with
`NoMemoryError` on pinned Ruby 3.3.13. The oracle runner rejected the failed
batch and did not replace its result file. No passing fixture was adopted
from that batch.

This exposes an incomplete numeric compatibility area. Very large shift
counts do not all produce the same exception: Ruby checks the resulting
digit count and representable allocation size before attempting allocation.
See [Ruby 3.3.13's big_shift2 and big_shift3](https://raw.githubusercontent.com/ruby/ruby/v3_3_13/bignum.c).
The existing oversized-count fixtures do not establish full allocation-error
parity.

The Calculator exception-control tests use the already-verified native bounds
error `"a"[9223372036854775808]`. Huge-shift allocation behavior remains a
separate outstanding item; it is not counted as passing Calculator coverage.
