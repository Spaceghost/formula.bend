# Compatibility contract and work remaining

## Ruby Dentaku baseline

Reference: rubysolo/dentaku commit
`1b9950be405ecb0d425f8683447b58cf29796d1f` (MIT).
This implementation currently shares only the small AST subset listed in README.

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

Remaining delivery: public formula.bend and nelua-bend repositories, Nelua backend,
Imba interface, and clean project sites under spacegho.st on Cloudflare.
