-- A malformed fixture must fail before any partial result can count as a pass.
local runtime = assert(arg[1], 'usage: lua tools/check-wire.lua JS_RUNTIME SCRIPT SCRATCH | NATIVE_BINARY --native SCRATCH')
local script = assert(arg[2], 'missing compiled script')
local scratch = assert(arg[3], 'missing scratch directory')
local native = script == '--native'
local cases = dofile('compat/corpus-wire-invalid.lua')
local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function read(path)
  local file = assert(io.open(path, 'rb')); local result = assert(file:read('*a')); assert(file:close()); return result
end
for i, case in ipairs(cases) do
  local prefix = scratch .. '/wire-invalid-' .. i
  local file = assert(io.open(prefix .. '.input', 'wb')); assert(file:write(case.input)); assert(file:close())
  local command_args = {quote(runtime)}
  if not native then command_args[#command_args+1] = quote(script) end
  command_args[#command_args+1] = quote(prefix .. '.input')
  if native then
    for _, value in ipairs{'+RTS', '--gpu', 'off', '--threads', '1'} do command_args[#command_args+1] = quote(value) end
  end
  for _, value in ipairs{'>', quote(prefix .. '.out'), '2>', quote(prefix .. '.err')} do command_args[#command_args+1] = value end
  local command = table.concat(command_args, ' ')
  local ok, kind, code = os.execute(command)
  assert(not ok and kind == 'exit' and code == 1, 'malformed corpus did not fail: ' .. i)
  assert(read(prefix .. '.out') == '', 'malformed corpus emitted partial results: ' .. i)
  assert(read(prefix .. '.err') == case.message .. '\n', 'wrong malformed-corpus diagnostic: ' .. i .. '\n' .. read(prefix .. '.err'))
end
print(#cases .. ' malformed corpus inputs rejected without partial results')
