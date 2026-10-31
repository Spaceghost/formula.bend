local IntegerContext = dofile((debug.getinfo(1, 'S').source:match('^@(.*/)') or './') .. 'integer-context.lua')
-- Runtime fixture data keeps corpus size out of the compiled GPU program.
local cases = dofile(assert(arg[1], 'usage: lua tools/generate-wire.lua CASES.lua OUTPUT'))
local output = assert(arg[2], 'missing output path')
assert(#cases > 0, 'empty corpus')
local function text(tag, value)
  return tag .. assert(utf8.len(value), 'invalid UTF-8 input') .. ':' .. value
end
local function value(item)
  local kind = type(item)
  if kind == 'string' then return text('s', item) end
  if kind == 'boolean' then return item and 't' or 'f' end
  if kind == 'number' then
    assert(math.type(item) == 'integer', 'use typed decimal input')
    return text('i', tostring(item))
  end
  assert(kind == 'table', 'unsupported corpus value')
  if item.null then return 'n' end
  if item.symbol then return text('y', item.symbol) end
  if item.integer then return text('i', IntegerContext.canonical(item.integer)) end
  if item.decimal then return text('d', item.decimal) end
  local parts = {}
  if item.hash then
    parts[1] = 'h'
    local seen = {}
    for _, pair in ipairs(item.hash) do
      assert(#pair == 2, 'invalid hash pair')
      local key = value(pair[1])
      assert(not seen[key], 'duplicate hash key')
      seen[key] = true
      parts[#parts+1] = key
      parts[#parts+1] = value(pair[2])
    end
    parts[#parts+1] = '}'
  else
    parts[1] = 'a'
    for _, field in ipairs(item) do parts[#parts+1] = value(field) end
    parts[#parts+1] = ']'
  end
  return table.concat(parts)
end
local function bindings(case)
  local fragments, keys = {'a'}, {}
  for key in pairs(case.context or {}) do keys[#keys+1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do
    fragments[#fragments+1] = 'a' .. text('s', key) .. value(case.context[key]) .. ']'
  end
  keys = {}
  for key in pairs(case.symbol_context or {}) do keys[#keys+1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do
    fragments[#fragments+1] = 'a' .. text('y', key) .. value(case.symbol_context[key]) .. ']'
  end
  fragments[#fragments+1] = ']'
  return table.concat(fragments)
end
local file = assert(io.open(output, 'wb'))
local expected = assert(io.open(output .. '.expected', 'w'))
assert(file:write('a'))
local seen = {}
for _, case in ipairs(cases) do
  assert(not seen[case.id], 'duplicate case id: ' .. case.id)
  seen[case.id] = true
  assert(not case.id:find('[\t\r\n]'), 'invalid case id')
  assert(type(case.expected) == 'string' and #case.expected > 0, 'missing golden result')
  local operation = case.operation or 'evaluate'
  local json = operation:sub(1, 5) == 'json_'
  if json then operation = operation:sub(6) end
  assert(file:write('a', text('s', case.id), text('s', case.formula), text('s', operation), bindings(case), case.sensitive and 't' or 'f', json and 't' or 'f', ']'))
  assert(expected:write(case.id, '\t', case.expected, '\n'))
end
assert(file:write(']\n'))
assert(file:close()); assert(expected:close())
print(#cases .. ' runtime corpus cases encoded')
