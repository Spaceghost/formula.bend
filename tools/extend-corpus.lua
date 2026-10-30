-- Append a verified batch. Never adopt an oracle result before Bend matches it.
local input = assert(arg[1], 'usage: lua tools/extend-corpus.lua CASES.lua ORACLE.tsv ACTUAL.tsv')
local oracle_path = assert(arg[2], 'missing oracle output')
local actual_path = assert(arg[3], 'missing Bend output')
local function read(path)
  local file = assert(io.open(path, 'r')); local value = assert(file:read('*a')); file:close(); return value
end
local function write(path, value)
  local file = assert(io.open(path, 'w')); assert(file:write(value)); assert(file:close())
end
local function literal(value)
  local kind = type(value)
  if kind == 'string' then return string.format('%q', value) end
  if kind == 'number' or kind == 'boolean' then return tostring(value) end
  assert(kind == 'table', 'unsupported fixture field: ' .. kind)
  local parts = {}
  if #value > 0 then
    for i, item in ipairs(value) do parts[i] = literal(item) end
  else
    local keys = {}; for key in pairs(value) do keys[#keys+1] = key end; table.sort(keys)
    for i, key in ipairs(keys) do parts[i] = '[' .. literal(key) .. ']=' .. literal(value[key]) end
  end
  return '{' .. table.concat(parts, ', ') .. '}'
end
local oracle = read(oracle_path)
assert(oracle == read(actual_path), 'Bend output differs from oracle; no fixtures were changed')
local values, rows = {}, 0
for id, value in oracle:gmatch('([^\n\t]+)\t([^\n]*)\n') do
  assert(not values[id], 'duplicate oracle id: ' .. id)
  values[id], rows = value, rows + 1
end
local old = dofile('compat/scalar-cases.lua')
local seen = {}; for _, case in ipairs(old) do seen[case.id] = true end
local cases, additions = dofile(input), {}
assert(#cases == rows, 'oracle count differs from batch count')
for _, case in ipairs(cases) do
  assert(not seen[case.id], 'case already exists: ' .. case.id)
  seen[case.id] = true
  case.expected = assert(values[case.id], 'missing oracle id: ' .. case.id)
  additions[#additions+1] = '  ' .. literal(case) .. ',\n'
end
local source, replacements = read('compat/scalar-cases.lua'):gsub('}%s*$', function()
  return table.concat(additions) .. '}\n'
end)
assert(replacements == 1, 'cannot locate fixture table end')
assert(load(source), 'generated fixture table is invalid Lua')
local complete_oracle = read('compat/scalar-oracle.tsv') .. oracle
write('compat/scalar-cases.lua', source)
write('compat/scalar-oracle.tsv', complete_oracle)
print(#cases .. ' verified cases added; ' .. (#old + #cases) .. ' total')
