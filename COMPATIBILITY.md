# Compatibility contract and work remaining

## Ruby Dentaku baseline

Reference: rubysolo/dentaku commit
`1b9950be405ecb0d425f8683447b58cf29796d1f` (MIT).
The implemented parser, bindings, functions, and numeric subset are listed in README.

The upstream README, lib/dentaku/calculator.rb, parser.rb, tokenizer.rb,
numeric_parser.rb, ast/functions/if.rb, and spec suite are authoritative evidence
for Ruby compatibility. Upstream IF uses Ruby truthiness; our current Boolean-only
condition prototype does not yet implement the complete value model.

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

Forward copying is the only implemented reference operation. Parsing, backward
copying, bounds errors, resolution, and rendering are pending.

Excel and Sheets disagree on functions, coercions, errors, dates, locale, and
rounding. Separate compatibility profiles need separate test fixtures. XLSX
import/export and Google Sheets interchange are part of the delivery scope and
remain unimplemented. A formula library alone does not establish file parity.

## Parallel execution and delivery

Use balanced batches of independent formulas and dependency-ready cells. Keep
short-circuit branches lazy and deterministic errors stable. Test JS, native CPU,
CUDA, and Metal separately. Record benchmark inputs, sizes, backend, hardware,
thread count, and timings before making performance claims.

The formula.bend repository is public. Remaining delivery: the public nelua-bend repository, Nelua backend,
Imba interface, and clean project sites under spacegho.st on Cloudflare.

## Numeric implementation status

Signed integer and fixed-point decimal addition, subtraction, and multiplication use exact
base-10 coefficients. Parsed integers with more than three digits remain in this
representation; arithmetic avoids machine-word coefficient overflow. This also
avoids large unary Nat reductions in proof checking. The regression suite covers
24-digit carry and products above the native Nat limit, but is not a complete
numeric compatibility corpus. Division, exponent parsing,
rounding policies, and coercions remain required work.

Current functions: SUM (one or more numeric scalar arguments), IF (three arguments,
Boolean guard, lazy branches), and NOT (one Boolean argument). Arrays, numeric
string coercion, Ruby truthiness, and remaining built-ins are still pending.

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
