# Float-to-BigDecimal coercion profiles

`BinaryBigDecimal.from_float` returns a signed exact decimal or an explicit
non-finite descriptor. Its profiles model two distinct paths in pinned
BigDecimal 3.1.5 / Ruby 3.3.13 with default numeric settings. They are standalone
building blocks; evaluator Float integration remains open.

`Implicit` models BigDecimal's coercion of a Float operand. The reference uses
shortest-decimal conversion, then truncates the resulting coefficient to sixteen
significant digits if it contains seventeen. It does not round that last digit.
`ShortestText` models `BigDecimal(float.to_s, 16)`, which parses every digit of
the string. The precision argument does not truncate a string argument.

For the Float immediately above one, implicit coercion yields exactly one,
while the text path yields `1.0000000000000002`. Ruby consequently considers
`BigDecimal("1")` equal to that Float, while Integer `1` compares unequal to it.
These behaviors require separate mixed comparison and arithmetic paths; a
single approximate numeric conversion would erase the distinction.

Dentaku's division and modulo methods explicitly convert their right operand
through the text path. The left operand can subsequently undergo BigDecimal's
implicit coercion. Ordinary mixed BigDecimal arithmetic also uses implicit
coercion. Integer/Float arithmetic and comparison need their own exact rules;
they must not be routed through this BigDecimal profile.

The implementation reuses the exact shortest-decimal search, truncates only
when the selected profile requires it, and preserves signed zero, infinity and
NaN classification. Lua generates 310 word-based cases for both profiles from
named boundaries and seeded random Floats. The reference invokes
`BigDecimal('0').coerce(float).first` or `BigDecimal(float.to_s, 16)` directly.

Sources: pinned
[BigDecimal conversion and coercion](https://github.com/ruby/bigdecimal/blob/v3.1.5/ext/bigdecimal/bigdecimal.c)
(`rb_float_convert_to_BigDecimal`) and
[Dentaku arithmetic](https://github.com/rubysolo/dentaku/blob/1b9950be405ecb0d425f8683447b58cf29796d1f/lib/dentaku/ast/arithmetic.rb)
(`decimal`, `Division`, `Modulo`). Global BigDecimal modes, other releases,
and evaluator dispatch remain outside this standalone checkpoint.
