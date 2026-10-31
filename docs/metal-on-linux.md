# Metal execution on Fedora: investigation, 2026-10-31

No Mac is required for project development. A translated Metal execution must
be identified separately from Apple's native Metal runtime. No formula.bend
Metal execution or Metal benchmark has passed yet.

Two primary-source candidates were inspected:

- [metal2vk](https://github.com/joshuaswarren/metal2vk), HEAD
  `83880cba8d6d29a5fbdc0476284b915b6600eed2`: takes Metal compute source
  through a Metal standard-library shim, Clang C++ for OpenCL, and patched
  clspv to SPIR-V. Its documented source route uses open tools and requires no
  Apple compiler. The current build calls for LLVM 23 and Vulkan 1.3 at runtime.
  Upstream orchestration includes Python; project tooling must remain Lua.
  Inspect and reproduce the actual compiler invocations rather than importing
  its Python runner into formula.bend.
- [metal2vulkan](https://github.com/steelbrain/metal2vulkan), HEAD
  `219f01365dc4c8eb346816c405b5b17403793764`: translates Metal AIR or
  metallib input and provides a Vulkan-backed Metal-shaped device API. The
  inspected README requires Rust 1.98 and Vulkan 1.2. This does not itself
  establish a Linux MSL-source-to-AIR compiler route for generated Bend code.

Bend 2.0.39's generated C for source `5103172` contains an MSL `bend_dev`
entrypoint with heap and pass buffers, dynamic threadgroup vote memory, grid,
row and lane builtins. Device code uses 32-bit atomic load/exchange/CAS,
device fences, threadgroup barriers, and 64-bit heap words. Its Metal 3.2
branch also uses coherent device address spaces. A useful smoke test must
exercise these synchronization/address-space features, not only arithmetic.

Next: inspect the pinned translator's shim and compiler support for those exact
features, translate a small Bend generated kernel, validate its SPIR-V, and
execute it through Vulkan on the P4000 with fallback disabled and checked
outputs. Only then attempt the frozen formula corpus. Retain translator,
compiler and driver versions, source/shader/output hashes, synchronization and
precision settings, and explicit translated-Metal labeling. This investigation
is not a benchmark or a pass for either candidate.
