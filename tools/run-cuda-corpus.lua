-- Compile one program, then load every fixture at runtime. This avoids both
-- per-batch shader compilation and compile-time specialization to the inputs.
local project = assert(arg[1], 'usage: lua tools/run-cuda-corpus.lua PROJECT BEND_PACKAGE CUDA_TOOLKIT SCRATCH [CASES.lua]')
local compiler = assert(arg[2], 'missing Bend package directory')
local cuda = assert(arg[3], 'missing CUDA toolkit directory')
local scratch = assert(arg[4], 'missing scratch directory')
assert(not arg[6], 'runtime corpus checks do not take a batch size')
local profiles = {{input=arg[5] or project .. '/compat/scalar-cases.lua', prefix='build/cuda-corpus'}}
if not arg[5] then
  profiles[#profiles+1] = {input=project .. '/compat/enumeration-scale-cases.lua', prefix='build/cuda-scale'}
end
local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function run(args)
  local escaped = {}
  for i, value in ipairs(args) do escaped[i] = quote(value) end
  local ok, _, code = os.execute(table.concat(escaped, ' '))
  assert(ok, 'CUDA corpus command failed: ' .. tostring(code))
end
run({'mkdir', '-p', project .. '/build', scratch})
for _, profile in ipairs(profiles) do
  run({arg[-1] or 'lua', project .. '/tools/generate-wire.lua', profile.input, project .. '/' .. profile.prefix .. '.input'})
end
local args = {'podman', 'run', '--rm', '--cgroups=disabled', '--network=host',
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
/compiler/bin/bend compat/corpus-runtime.bend -o build/corpus-runtime.c
clang -std=c11 -O3 -DBEND_CUDA=1 -I/cuda/include -L/cuda/lib -L/cuda/lib/stubs build/corpus-runtime.c -lpthread -lm -lcuda -lnvrtc -o build/corpus-runtime
for profile in "$@"; do
  ./build/corpus-runtime "$profile.input" +RTS --gpu off --threads 1 > "$profile-cpu-1.actual"
  diff -u "$profile.input.expected" "$profile-cpu-1.actual"
  ./build/corpus-runtime "$profile.input" +RTS --gpu off --threads 8 > "$profile-cpu-8.actual"
  diff -u "$profile.input.expected" "$profile-cpu-8.actual"
  echo "CPU pool checks passed: $profile"
done
./build/corpus-runtime +RTS --gpu-build
for profile in "$@"; do
  ./build/corpus-runtime "$profile.input" +RTS --gpu 1GB > "$profile.actual"
  diff -u "$profile.input.expected" "$profile.actual"
  sha256sum "$profile.input" "$profile.actual"
  echo "Required CUDA checks passed: $profile"
done
sha256sum build/corpus-runtime build/corpus-runtime.c build/corpus-runtime.gpu
]], 'corpus-check'}
for _, profile in ipairs(profiles) do args[#args+1] = profile.prefix end
run(args)
