-- Run from a frozen Git worktree. Source is mounted read-only; build and scratch
-- are separate writable mounts. Requires the existing clang 19 development image.
local project = assert(arg[1], 'usage: lua tools/run-native-corpus.lua FROZEN_WORKTREE BEND_PACKAGE SCRATCH')
local compiler = assert(arg[2], 'missing Bend package directory')
local scratch = assert(arg[3], 'missing scratch directory')
local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function command(args)
  local escaped = {}
  for i, value in ipairs(args) do escaped[i] = quote(value) end
  return table.concat(escaped, ' ')
end
local function run(args)
  local ok, _, code = os.execute(command(args))
  assert(ok, 'native corpus command failed: ' .. tostring(code))
end
run({'mkdir', '-p', project .. '/build', scratch})
run({arg[-1] or 'lua', project .. '/tools/generate-corpus.lua', project .. '/compat/scalar-cases.lua', project .. '/build/scalar-corpus'})
run({'podman', 'run', '--rm', '--cgroups=disabled', '--network=host',
  '--security-opt', 'label=disable',
  '-e', 'BEND_NO_TELEMETRY=1', '-e', 'HOME=/tmp', '-e', 'TMPDIR=/tmp',
  '-v', project .. ':/work:ro', '-v', project .. '/build:/work/build:rw',
  '-v', compiler .. ':/compiler:ro', '-v', scratch .. ':/tmp:rw',
  '-w', '/work', os.getenv('FORMULA_NATIVE_IMAGE') or 'localhost/bend-jev:dev',
  'bash', '-lc', [[set -e
/compiler/bin/bend build/scalar-corpus.bend -o build/scalar-corpus-native
./build/scalar-corpus-native +RTS --threads 1 > build/scalar-corpus-native-1.actual
diff -u compat/scalar-oracle.tsv build/scalar-corpus-native-1.actual
./build/scalar-corpus-native +RTS --threads 8 > build/scalar-corpus-native-8.actual
diff -u compat/scalar-oracle.tsv build/scalar-corpus-native-8.actual
sha256sum build/scalar-corpus-native
]]})
