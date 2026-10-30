-- Toolchain correctness only: this does not establish formula GPU parity.
local project = assert(arg[1], 'usage: lua tools/run-cuda-smoke.lua FROZEN_WORKTREE BEND_PACKAGE CUDA_TOOLKIT SCRATCH')
local compiler = assert(arg[2], 'missing Bend package directory')
local cuda = assert(arg[3], 'missing CUDA toolkit directory')
local scratch = assert(arg[4], 'missing scratch directory')
local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function run(args)
  local escaped = {}
  for i, value in ipairs(args) do escaped[i] = quote(value) end
  local ok, _, code = os.execute(table.concat(escaped, ' '))
  assert(ok, 'CUDA toolchain check failed: ' .. tostring(code))
end
run({'mkdir', '-p', project .. '/build', scratch})
run({'podman', 'run', '--rm', '--cgroups=disabled', '--network=host',
  '--device', os.getenv('FORMULA_CUDA_DEVICE') or 'nvidia.com/gpu=0',
  '--security-opt', 'label=disable', '-e', 'BEND_NO_TELEMETRY=1',
  '-e', 'HOME=/tmp', '-e', 'TMPDIR=/tmp', '-e', 'CUDA_HOME=/cuda',
  '-e', 'LIBRARY_PATH=/cuda/lib/stubs',
  '-e', 'LD_LIBRARY_PATH=/cuda/lib:/usr/local/nvidia/lib64:/usr/local/nvidia/lib',
  '-v', project .. ':/work:ro', '-v', project .. '/build:/work/build:rw',
  '-v', compiler .. ':/compiler:ro', '-v', cuda .. ':/cuda:ro',
  '-v', scratch .. ':/tmp:rw', '-w', '/work',
  os.getenv('FORMULA_NATIVE_IMAGE') or 'localhost/bend-jev:dev',
  'bash', '-lc', [[set -e
cp compat/cuda-toolchain-smoke.bend build/cuda-toolchain-smoke.bend
/compiler/bin/bend build/cuda-toolchain-smoke.bend -o build/cuda-toolchain-smoke
./build/cuda-toolchain-smoke +RTS --gpu off > build/cuda-toolchain-smoke-cpu.actual
# An explicit GPU size requests required GPU mode; initialization failures
# terminate rather than silently executing the bang on the CPU pool.
./build/cuda-toolchain-smoke +RTS --gpu 1GB > build/cuda-toolchain-smoke-gpu.actual
printf '16384\n' > build/cuda-toolchain-smoke.expected
diff -u build/cuda-toolchain-smoke.expected build/cuda-toolchain-smoke-cpu.actual
diff -u build/cuda-toolchain-smoke.expected build/cuda-toolchain-smoke-gpu.actual
sha256sum build/cuda-toolchain-smoke.bend build/cuda-toolchain-smoke build/cuda-toolchain-smoke.gpu
]]})
