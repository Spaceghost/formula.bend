# Compatibility contract and work remaining

## Ruby Dentaku baseline

Reference: rubysolo/dentaku commit
`1b9950be405ecb0d425f8683447b58cf29796d1f` (MIT).
The implemented parser, bindings, functions, and numeric subset are listed in README.

The upstream README, lib/dentaku/calculator.rb, parser.rb, tokenizer.rb,
numeric_parser.rb, ast/functions/if.rb, and spec suite are authoritative evidence
for Ruby compatibility. Upstream IF uses Ruby truthiness; our earlier Boolean-only
condition prototype has been replaced with Ruby truthiness for scalar values.

1. Parse formula strings with upstream precedence, literals, names, and errors;
   preserve Integer and BigDecimal behavior without silently substituting F32.
2. Implement bindings, store/bind, case sensitivity, transient contexts,
   evaluate versus evaluate!, AST caching, and custom function registration.
3. Implement the built-in function inventory, arrays, date/time and strings,
   lazy IF/CASE/AND/OR, and volatile-function behavior.
4. Keep syntactic identifiers separate from context-sensitive dependencies;
   implement dependency graphs, cycles, and incremental/bulk evaluation.
5. Build a differential corpus against the pinned Ruby implementation; record
   expected values, errors, dependencies, and intentionally different behavior.

## Spreadsheet extensions

References:
- https://support.microsoft.com/en-us/office/switch-between-relative-absolute-and-mixed-references-dfec08cd-ae65-4f56-839e-5f0d8d0baca9
- https://developers.google.com/workspace/sheets/api/guides/concepts

Implement A1, $A$1, $A1, A$1; R1C1 absolute and signed relative coordinates;
sheet-qualified and quoted names; ranges; names; and mixed notation in a formula
under an explicit dialect. Preserve source dialect in the AST. Ambiguous names
must be resolved by documented dialect rules, never guessed silently.

The address layer parses and renders unqualified A1 and R1C1, with anchors,
signed offsets, and bounded resolution. Formula integration, sheet qualifiers,
ranges, dialect-specific bounds, and names remain pending.

Excel and Sheets disagree on functions, coercions, errors, dates, locale, and
rounding. Separate compatibility profiles need separate test fixtures. XLSX
import/export and Google Sheets interchange are part of the delivery scope and
remain unimplemented. A formula library alone does not establish file parity.

## Parallel execution and delivery

Use balanced batches of independent formulas and dependency-ready cells. Keep
short-circuit branches lazy and deterministic errors stable. Test JS, native CPU,
CUDA, and Metal separately. Record benchmark inputs, sizes, backend, hardware,
thread count, and timings before making performance claims.

Remaining delivery for formula.bend includes full Dentaku parity, the target
shootout, an Imba interface, and a project site under spacegho.st on Cloudflare.

## Numeric implementation status

Signed integer and fixed-point decimal addition, subtraction, and multiplication use exact
base-10 coefficients. Parsed integers with more than three digits remain in this
representation; arithmetic avoids machine-word coefficient overflow. This also
avoids large unary Nat reductions in proof checking. The regression suite covers
24-digit carry and products above the native Nat limit, but is not a complete
numeric compatibility corpus. Scientific and hexadecimal literals and numeric
strings are supported. Modulo,
percentages, powers, complete rounding profiles, and coercions remain required.

Current scalar functions: SUM, MUL, MIN, MAX, AVG, ABS, IF, NOT, AND, OR, XOR,
COUNT, ROUND, ROUNDUP, ROUNDDOWN, LEFT, RIGHT, MID, LEN, FIND, SUBSTITUTE,
CONCAT, CONTAINS, and SWITCH. IF uses Ruby truthiness and lazy branches;
NOT uses Ruby truthiness. Arrays support nesting, numeric aggregate flattening,
concatenation, subtraction, repetition, equality, and postfix access. String
indexing and null-safe access are implemented. Complete numeric-string coercion,
array-oriented built-ins, hash/member access, and other built-ins remain pending.
Scientific exponents are limited to 14 significant exponent digits and runtime
Nat scales; special BigDecimal values and full numeric-class parity are pending.

Unary minus binds more tightly than multiplication; binary subtraction shares
addition precedence and is left-associative. Positive and negative operands use
aligned exact magnitudes with decimal borrowing. Negative zero is normalized to
ordinary zero, which differs from some BigDecimal representations and still
needs an explicit compatibility policy.

## Rounding profile

ROUND uses half-away-from-zero and defaults to zero decimal places. ROUNDUP is
ceiling; ROUNDDOWN is floor, following the pinned Ruby Dentaku source. In
particular, ROUNDUP(-1.21, 1) is -1.2 here. Excel's ROUNDUP/ROUNDDOWN use different
negative-number rules and require a separate profile, not a change to this Ruby
baseline. Fractional precision arguments truncate toward zero, matching to_i.
Negative precision rounds to tens, hundreds, etc. Precision must fit the current
index range (at most 14 significant integer digits); larger precision arguments
produce an explicit error. This is an implementation limit, not full Ruby parity.

## Division profile

The `/` operator has multiplication precedence and left associativity. Its current
default precision follows Ruby 3.3.13 / BigDecimal 3.1.5's operand-dependent
allocation and base-10^9 alignment, with half-away-from-zero rounding. Seven
reference cases match all digits after integral `.0` display normalization;
this does not establish full BigDecimal parity. The recorded source and results
are in compat/. Core.divide_at offers explicit fractional places and rounding.

Long division retains the exact remainder before rounding. Zero divisors produce
an explicit error. Numeric-string coercion, nonfinite values, global BigDecimal
modes, Ruby version profiles, and exact exception-class parity remain unfinished.

## Address representation

src/address.bend stores each axis as Fixed(zero-based index) or Displaced(signed
offset). Parsing A1 takes the formula cell's origin; R1C1 directly supplies axes.
Copying a formula preserves this representation and resolves it at the new origin.
The original notation is retained. The syntax parser accepts indices/offsets up to
2^32-1; resolution uses explicit row/column limits and rejects underflow or bounds
violations. Excel and Sheets limits must be selected by the future dialect API.

The standalone layer handles $A$1, $A1, A$1, A1, R1C1, R[-1]C[2], RC, and mixed
R1C1 axes. It does not yet change formula tokenization or variable lookup: A1 in
an ordinary Ruby-style formula remains an identifier. Quoted sheet names, ranges,
external workbook names, structured references, and mixed notation inside a
formula remain required work. src/reference.bend is the earlier forward-copy
prototype; its original laws remain intact while callers migrate to address.bend.

## Logical operators and dependency queries

Infix AND/OR/XOR share the upstream precedence of zero and associate leftward.
Prefix NOT and ! bind below comparisons and above infix logic. Function NOT
retains its broader Ruby truthiness rules; prefix NOT has static logical-operand
validation. AND/OR preserve lazy value evaluation and right-decisive unbound
recovery. The alias-spacing rules are covered by differential fixtures.

Syntactic identifier queries deduplicate and do not prune or evaluate guards.
Resolved dependency queries handle bindings and IF/AND/OR guard pruning. Formula
evaluation now performs the Calculator-style missing-dependency preflight before
Core AST evaluation. Current bindings hold values, not stored formula nodes;
custom/volatile functions, cycles, and bulk solving remain required work.

## Function argument nodes

Function calls retain explicit argument nodes. SUM, MUL, MIN, MAX, AVG, ABS, AND,
OR, and XOR support covered scalar cases, including numeric-string coercion,
empty calls, and eager errors. Arrays and flattening remain pending. Function
argument dependencies retain repeated names; identifiers deduplicate at their
public boundary. Enclosing operations deduplicate dependencies as upstream does.
ROUND preserves repeated dependencies in its two arguments as well.
