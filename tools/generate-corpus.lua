local input = assert(arg[1], 'usage: lua tools/generate-corpus.lua CASES.lua OUTPUT_PREFIX')
local prefix = assert(arg[2], 'missing output prefix')
local cases = dofile(input)
local function bend_string(s)
  return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
end
local function json_string(s)
  return '"' .. s:gsub('[%z\1-\31\\"]', function(c)
    if c == '"' then return '\\"' end
    if c == '\\' then return '\\\\' end
    return ('\\u%04x'):format(c:byte())
  end) .. '"'
end
-- Typed context values preserve exact decimal inputs across Lua, Ruby and Bend.
-- Plain Lua strings/booleans/integers are supported, as are array tables,
-- {decimal='...'}, {integer='...'}, and {null=true}.
local function context_value(value)
  local kind = type(value)
  if kind == 'string' then
    return 'Core.TextValue{' .. bend_string(value) .. '}', '{"text":' .. json_string(value) .. '}'
  elseif kind == 'boolean' then
    return 'Core.Logical{' .. (value and 'True{}' or 'False{}') .. '}', tostring(value)
  elseif kind == 'number' then
    assert(math.type(value) == 'integer', 'use {decimal="..."} for decimal context values')
    return 'Parser.evaluate(' .. bend_string(tostring(value)) .. ', Nil{}, False{})', '{"integer":' .. json_string(tostring(value)) .. '}'
  end
  assert(kind == 'table', 'unsupported context value: ' .. kind)
  if value.null then return 'Core.NullValue{}', 'null' end
  if value.decimal or value.integer then
    local key = value.decimal and 'decimal' or 'integer'
    local text = value[key]
    local expression = 'Parser.evaluate(' .. bend_string(text) .. ', Nil{}, False{})'
    if key == 'decimal' then expression = 'Core.decimal_result(' .. expression .. ')' end
    return expression, '{' .. json_string(key) .. ':' .. json_string(text) .. '}'
  end
  local expressions, encoded = {}, {}
  for i, item in ipairs(value) do expressions[i], encoded[i] = context_value(item) end
  local expression = 'Core.ArrayNil{}'
  for i = #expressions, 1, -1 do expression = 'Core.ArrayCons{' .. expressions[i] .. ', ' .. expression .. '}' end
  return expression, '[' .. table.concat(encoded, ',') .. ']'
end
local function context_values(context)
  local keys, expressions, encoded = {}, {}, {}
  for name in pairs(context or {}) do keys[#keys+1] = name end
  table.sort(keys)
  for i, name in ipairs(keys) do
    local expression, json = context_value(context[name])
    expressions[i] = 'Core.Bound{' .. bend_string(name) .. ', ' .. expression .. '}'
    encoded[i] = json_string(name) .. ':' .. json
  end
  return #expressions == 0 and 'Nil{}' or '[' .. table.concat(expressions, ', ') .. ']', '{' .. table.concat(encoded, ',') .. '}'
end
local program = assert(io.open(prefix .. '.bend', 'w'))
local expected = assert(io.open(prefix .. '.expected', 'w'))
local formulas = assert(io.open(prefix .. '.formulas.tsv', 'w'))
program:write('import Base\nimport ../src/core.bend as Core\nimport ../src/parser.bend as Parser\n\ndef main() -> IO(Unit):\n  do IO<Unit>:\n')
local ids = {}
for _, case in ipairs(cases) do
  assert(not ids[case.id], 'duplicate id: ' .. case.id)
  ids[case.id] = true
  assert(not case.id:find('[\t\r\n]') and not case.formula:find('[\t\r\n]'), 'TSV control characters unsupported')
  local operation = case.operation or 'evaluate'
  local context, encoded_context = context_values(case.context)
  local sensitive = case.sensitive and 'True{}' or 'False{}'
  local call
  if operation == 'identifiers' then
    call = 'Parser.names_snapshot(Parser.identifiers(' .. bend_string(case.formula) .. ', ' .. sensitive .. '))'
  elseif operation == 'dependencies' then
    call = 'Parser.names_snapshot(Parser.dependencies(' .. bend_string(case.formula) .. ', ' .. context .. ', ' .. sensitive .. '))'
  elseif operation == 'class' then
    call = 'Parser.class_snapshot(' .. bend_string(case.formula) .. ', ' .. context .. ', ' .. sensitive .. ')'
  elseif operation == 'coerce' or operation == 'coerce_class' then
    local show = operation == 'coerce' and 'snapshot' or 'class_snapshot'
    call = 'Core.' .. show .. '(Core.require_numeric(Core.lookup(' .. context .. ', "input", ' .. sensitive .. ')))'
  else
    assert(operation == 'evaluate', 'unknown operation: ' .. operation)
    call = 'Parser.snapshot(' .. bend_string(case.formula) .. ', ' .. context .. ', ' .. sensitive .. ')'
  end
  program:write('    IO.print(', bend_string(case.id .. '\t'), ' ++ ', call, ')\n')
  expected:write(case.id, '\t', case.expected, '\n')
  formulas:write(case.id, '\t', case.formula, '\t', operation, '\t', encoded_context, '\t', tostring(not not case.sensitive), '\n')
end
program:close(); expected:close(); formulas:close()
