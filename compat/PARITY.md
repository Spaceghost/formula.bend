# Dentaku parity gates

Baseline: rubysolo/dentaku at 1b9950be405ecb0d425f8683447b58cf29796d1f.
The goal is behavioral parity with its rules, tests, and implementation. The
Bend regression suite is supporting evidence; it does not replace that baseline.

The inventory lists every upstream spec file. `partial` means some related
behavior exists, not that the upstream file passes against Bend. `unassessed`
means it still needs a rule-by-rule port. Source example-line counts do not
count dynamically generated examples. The executed RSpec JSON catalog is the
authoritative upstream runtime inventory.

## Required rule families

1. Tokenization and parsing: literals, exponents, hex, aliases, operators and
   precedence/associativity, strings, arrays, access, CASE, custom functions,
   exact rejection rules, and diagnostics.
2. Values and built-ins: numeric types/coercions, null, Ruby truthiness, lazy
   logic, arrays, strings, date/time, rounding, all registered built-ins,
   arity/type rules, and failure behavior.
3. Calculator API: evaluate versus evaluate!, store/bind, temporary contexts,
   case sensitivity, aliases, caching, custom functions, and registration.
4. Analysis: syntactic identifiers, resolution-aware dependencies, branch
   pruning, volatile functions, cycles, bulk solving, visitors and formatting.
5. Verification: port each upstream scenario or document an explicit language
   adaptation; run differential cases against the pinned Ruby implementation.
   Any unsupported case remains a failing or explicitly incomplete parity item.

## Shootout gate

Performance comparisons begin after the shared parity corpus passes. Use the
same formulas, bindings, expected values/errors/dependencies, work counts, and
numeric profile on every backend. Benchmark parsing, cached AST evaluation,
independent batches, and dependency-driven recalculation separately.

Targets: JavaScript; native CPU with one thread and multiple threads; CUDA; Metal.
Record compiler/runtime versions, hardware, memory, thread counts, GPU use and
fallback status, workload and sizes, warmup, repetitions, timings, and result
checksums. Include Ruby Dentaku as a baseline. Report unsupported hardware as
unmeasured. A CPU fallback must never be labeled a GPU measurement. Do not claim
speedups from different precision, omitted work, or skipped compatibility cases.

## Current evidence

The unchanged upstream suite passes 713 examples with zero failures and 96.82%
line coverage in the Ruby reference environment. `reference-summary.json` and
`upstream-spec-catalog.json` record that run. These results describe Ruby only.

The Lua-driven scalar corpus has 31 cases matched against Ruby values or parse
error classification. It covers truthiness, strings/null, comparisons, selected
numeric-string coercions, and static operand rejection. It is a small subset of
the upstream catalog. Native error classes/messages, all calculator methods,
arrays, other built-ins, logical operators, custom functions, dependencies, and
visitors still require parity work. Hex/exponent numeric-string coercion remains
unfinished. No spec family is marked complete merely because this subset passes.

The static analysis pass never evaluates guards or functions. It distinguishes
literal strings rejected as arithmetic operands from variables that can resolve
to numeric strings. Validation visits unused branches too, matching parse-time
rejection independently of evaluation-time branch laziness.

## Reference runner

`tools/reference.Containerfile` pins the Ruby image manifest and adds Git for the
gemspec checks. Build it with chroot isolation on this host to avoid the observed
systemd container-creation stall. The oracle gems are installed in a mounted
cache: concurrent-ruby 1.3.5, rspec 3.13.0, pry 0.15.2, simplecov 0.22.0, and their
resolved dependencies. Keep the upstream checkout in a separate Git worktree.

```sh
lua tools/run-reference.lua UPSTREAM_WORKTREE GEMS_DIR CONTAINER_STORAGE RUNROOT
lua tools/upstream-inventory.lua UPSTREAM_WORKTREE
```

The runner mounts the actual Git common directory and runs the complete spec
suite without preloading Dentaku ahead of SimpleCov. Runtime outputs and coverage
stay in the upstream worktree. The application implementation remains Bend, and
the fixture generator and reference orchestration are Lua.

To refresh scalar oracle results after generating the corpus, run:

```sh
lua tools/run-oracle.lua PROJECT UPSTREAM GEMS STORAGE RUNROOT OUTPUT
```

The probe catches Dentaku errors and records their class; unexpected Ruby failures
abort without replacing the output. Compare the result before updating committed
goldens. Parser snapshots currently preserve parse-error classification, while
full runtime error-class/message parity remains unfinished. The 31-case scalar
corpus passes on JavaScript and native CPU. This is correctness verification,
not the requested performance shootout.

The upstream catalog and scenario inventory derive from MIT-licensed Dentaku;
its license is retained as LICENSE.dentaku. The current pinned source has 54 spec
files and 713 executed examples. The inventory status remains partial or
unassessed until the corresponding rules have been ported and verified.
