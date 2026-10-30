-- Bound checker memory while retaining every differential case in source order.
local input = assert(arg[1], 'usage: lua tools/run-corpus.lua CASES.lua OUTPUT_PREFIX BEND [BATCH_SIZE]')
local prefix = assert(arg[2], 'missing output prefix')
local bend = assert(arg[3], 'missing Bend executable')
local size = tonumber(arg[4] or '256')
assert(math.type(size) == 'integer' and size > 0, 'invalid batch size')
local cases = dofile(input)
assert(#cases > 0, 'empty corpus')
local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function run(args, output)
  local escaped = {}
  for i, value in ipairs(args) do escaped[i] = quote(value) end
  local command = table.concat(escaped, ' ')
  if output then command = command .. ' > ' .. quote(output) end
  local ok, _, code = os.execute(command)
  assert(ok, 'corpus command failed: ' .. tostring(code))
end
local output = assert(io.open(prefix .. '.actual', 'w'))
local lua = arg[-1] or 'lua'
for start = 1, #cases, size do
  local part = prefix .. '-part-' .. start
  run({lua, 'tools/generate-corpus.lua', input, part, '--slice', tostring(start), tostring(size)})
  run({bend, part .. '.bend'}, part .. '.actual')
  local file = assert(io.open(part .. '.actual'))
  assert(output:write(file:read('*a')))
  assert(file:close())
  assert(output:flush())
  print(('Checked cases %d–%d of %d'):format(start, math.min(start + size - 1, #cases), #cases))
end
assert(output:close())
