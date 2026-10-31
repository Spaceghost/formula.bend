-- Append a verified batch. Never adopt an oracle result before Bend matches it.
local input = assert(arg[1], 'usage: lua tools/extend-corpus.lua CASES.lua ORACLE.tsv ACTUAL.tsv [CASES_OUTPUT.lua ORACLE_OUTPUT.tsv]')
local oracle_path = assert(arg[2], 'missing oracle output')
local actual_path = assert(arg[3], 'missing Bend output')
assert((arg[4] == nil) == (arg[5] == nil), 'supply both corpus output paths')
local cases_path = arg[4] or 'compat/scalar-cases.lua'
local adopted_oracle_path = arg[5] or 'compat/scalar-oracle.tsv'
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
local existing = io.open(cases_path, 'r')
local old_source = existing and existing:read('*a') or 'return {\n}\n'
if existing then existing:close() end
local old = assert(load(old_source, '@' .. cases_path))()
local seen = {}; for _, case in ipairs(old) do seen[case.id] = true end
local cases, additions = dofile(input), {}
assert(#cases == rows, 'oracle count differs from batch count')
for _, case in ipairs(cases) do
  assert(not seen[case.id], 'case already exists: ' .. case.id)
  seen[case.id] = true
  case.expected = assert(values[case.id], 'missing oracle id: ' .. case.id)
  additions[#additions+1] = '  ' .. literal(case) .. ',\n'
end
local source, replacements = old_source:gsub('}%s*$', function()
  return table.concat(additions) .. '}\n'
end)
assert(replacements == 1, 'cannot locate fixture table end')
assert(load(source), 'generated fixture table is invalid Lua')
local existing_oracle = io.open(adopted_oracle_path, 'r')
local old_oracle = existing_oracle and existing_oracle:read('*a') or ''
if existing_oracle then existing_oracle:close() end
local complete_oracle = old_oracle .. oracle
write(cases_path, source)
write(adopted_oracle_path, complete_oracle)
print(#cases .. ' verified cases added; ' .. (#old + #cases) .. ' total')
