-- Execute the complete, unchanged upstream suite in the Ruby oracle container.
local worktree = assert(arg[1], 'usage: lua tools/run-reference.lua WORKTREE GEMS_DIR CONTAINER_ROOT RUNROOT')
local gems = assert(arg[2], 'missing gems directory')
local storage = assert(arg[3], 'missing container storage directory')
local runroot = assert(arg[4], 'missing container runroot')
local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function command(args)
  local escaped = {}
  for i, value in ipairs(args) do escaped[i] = quote(value) end
  return table.concat(escaped, ' ')
end
local pipe = assert(io.popen(command({'git','-C',worktree,'rev-parse','--path-format=absolute','--git-common-dir'})))
local common = assert(pipe:read('*l'), 'cannot locate upstream git directory')
assert(pipe:close(), 'upstream git lookup failed')
local args = {
  'podman','--root',storage,'--runroot',runroot,'run','--rm',
  '--cgroups=disabled','--network=host','--security-opt','label=disable',
  '-e','GEM_HOME=/gems','-e','GEM_PATH=/gems',
  '-v',gems .. ':/gems', '-v', common .. ':' .. common .. ':ro',
  '-v',worktree .. ':/reference','-w','/reference',
  os.getenv('FORMULA_REFERENCE_IMAGE') or 'localhost/formula-dentaku-reference:3.3.13',
  'ruby','-Ilib','/gems/bin/rspec','-I','spec',
  '--format','progress','--format','json','--out','upstream-results.json','spec',
}
local ok, _, code = os.execute(command(args))
if not ok then os.exit(code or 1) end
