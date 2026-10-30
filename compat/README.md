# Ruby division reference

Baseline: rubysolo/dentaku commit
`1b9950be405ecb0d425f8683447b58cf29796d1f`.

`ruby-division-oracle.txt` records the Ruby and BigDecimal versions and raw
results. `ruby-division-fixed.tsv` records the same seven formulas using
BigDecimal's fixed-point output. The reference ran in ruby:3.3-alpine with
concurrent-ruby 1.3.5. The image configuration digest was
`sha256:7544a24da62fd964daf0293dc222909af189cee034ebdbff785570a3be4e2904`.

`division-runtime.expected` removes only the `.0` suffix on an integral result
because formula.bend renders integral values without that suffix. All other
reference digits must match exactly. This is a seven-case differential corpus,
not complete division compatibility coverage.

The default precision calculation follows BigDecimal 3.1.5's `BigDecimal_divide`
and `VpDivd`, including its base-10^9 limb alignment. Other Ruby/BigDecimal
versions and global BigDecimal modes are not yet supported as profiles.

Reference source:
https://github.com/ruby/bigdecimal/blob/v3.1.5/ext/bigdecimal/bigdecimal.c
