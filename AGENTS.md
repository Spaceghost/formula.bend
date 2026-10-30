# Project instructions

Read the host storage policy. Use branches and direct master pushes, never force
push or create PRs unless the owner asks.

Run `bend guide` before Bend work. Keep contracts in LAWS.bend; never weaken them
to pass a gate. Run `bend PROOF.bend` before every commit. Parallelize independent
balanced computation; preserve lazy branches. State compatibility limits plainly.

The project is formula.bend, a reimplementation of Ruby Dentaku with additional
Excel/Google Sheets dialects. Preserve that identity and full scope. The engine
uses Bend 2; development tooling uses Lua and web source uses Imba only. Keep
separate compiler projects out of the product documentation.

Do not introduce Python tooling. When replacing Python, prefer Nelua unless
another option expresses the task better. Lua is appropriate for the existing
fixture generation and reference-process orchestration.
