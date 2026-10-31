# TokenMatcher compatibility

`src/token_matcher.bend` implements the matching rules from the pinned
Dentaku `TokenMatcher`. It operates on the public descriptors in
`src/token.bend`; integration with the parser's internal lexer and
`TokenScanner` remains unfinished.

## API

Import the module and construct a rule with `make(categories, values, children)`.
Categories and values are `Core.Value` scalars or nested arrays. A top-level
null means an unrestricted set. Arrays flatten recursively; nulls inside an
array remain actual keys. Duplicate keys preserve the first key. Membership
uses the supported Ruby Hash key identity profile, including the distinction
between an Integer and a BigDecimal with the same numeric value.

`category(name)`, `selected(category, value)`, and
`pair(category, first, second)` construct common symbol rules.
`builtin(name)` provides Dentaku's named matcher presets.
`accepts(matcher, token)` takes `Some{Token.Token}` or `None{}`.
An absent token never matches, including an inverted leaf.

`either(left, right)` combines alternatives. `invert`, `caret`, `star`,
and `plus` return new matchers. These functions are immutable; they do not
reproduce Ruby object mutation or aliasing. Keep the returned rule.

`get_categories`, `get_values`, `get_caret`, `get_minimum`,
`is_leaf`, and `leaf_matchers` expose the corresponding descriptor state.

## Stream matching

`match_stream(matcher, stream, negative, offset)` takes a list of optional
tokens and a signed offset represented by a Boolean sign and Nat magnitude.
It returns `Matched{accepted, tokens}`. A normal rule consumes at most one
token, `star` permits zero or more, and `plus` permits one or more.
Applying `plus` after `star` retains a zero minimum, as in Dentaku.

The input list bounds recursion. A negative offset within the stream first
visits its suffix, then index zero through the stream's end. An offset before
the negative beginning returns an empty match. This preserves Ruby Array
indexing rather than treating a negative offset as a slice. A null stream
entry ends matching.

The caret flag is metadata for the scanner; it does not change
`TokenMatcher#match` itself. A compound matcher accepts any child and ignores
its own invert flag. Combining matchers resets the new compound's caret and
quantifier state. Child quantifiers do not affect single-token acceptance.

## Verification scope

`tools/token-matcher-cases.lua` produces differential probes for all named
presets, scalar and nested key sets, immutable modifier sequences, alternatives,
nil tokens, numeric key identity, and positive/negative stream offsets.
Reference results come from the pinned Ruby source; they are adopted into
the corpus only after Bend agrees.

The value profile follows `Core.Value`. Arbitrary Ruby objects, Float
identity, mutable aliasing, scanner behavior, and raw-token visitor integration
are not established by these probes. These are matcher checks, not a claim of
complete Dentaku or spreadsheet parity.
