local IntegerContext = dofile((debug.getinfo(1, 'S').source:match('^@(.*/)') or './') .. 'integer-context.lua')
local input = assert(arg[1], 'usage: lua tools/generate-corpus.lua CASES.lua OUTPUT_PREFIX [--metadata-only | --slice START COUNT | --gpu | --gpu-slice START COUNT]')
local prefix = assert(arg[2], 'missing output prefix')
local metadata_only = arg[3] == '--metadata-only'
local gpu = arg[3] == '--gpu' or arg[3] == '--gpu-slice'
assert(arg[3] == nil or metadata_only or arg[3] == '--slice' or gpu, 'unknown generator option')
local cases = dofile(input)
local needs_stored = false
for _, case in ipairs(cases) do if case.operation == 'stored_value' then needs_stored = true end end
assert(#cases > 0, 'corpus must contain at least one case')
if arg[3] == '--slice' or arg[3] == '--gpu-slice' then
  local start, count = assert(tonumber(arg[4]), 'missing slice start'), assert(tonumber(arg[5]), 'missing slice count')
  assert(math.type(start) == 'integer' and math.type(count) == 'integer' and start >= 1 and count >= 1 and start <= #cases, 'invalid corpus slice')
  local selected = {}
  for i = start, math.min(start + count - 1, #cases) do selected[#selected+1] = cases[i] end
  cases = selected
end
local function bend_string(s)
  if s:find('[%z\1-\8\11\12\14-\31]') then
    local points = {}
    for _, cp in utf8.codes(s) do points[#points+1] = cp end
    local expression = 'SNil{}'
    for i = #points, 1, -1 do expression = 'SCon{Chr{' .. points[i] .. '}, ' .. expression .. '}' end
    return expression
  end
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
-- {decimal='...'}, {integer='...'}, {null=true}, {symbol='...'}, and ordered
-- {hash={{key,value},...}} entries with string/symbol keys. symbol_context
-- distinguishes symbol keys in the original calculator context.
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
  if value.symbol then
    return 'Core.SymbolValue{' .. bend_string(value.symbol) .. '}', '{"symbol":' .. json_string(value.symbol) .. '}'
  end
  if value.class or value.module then
    local category = value.class and 'class' or 'module'
    local name = value[category]
    assert(type(name) == 'string' and #name > 0, 'named references require a canonical name')
    assert(type(value.ancestors) == 'table', 'named references require their ordered ancestor names')
    local parents, encoded = {}, {}
    for i, parent in ipairs(value.ancestors) do
      assert(type(parent) == 'string' and #parent > 0, 'invalid named ancestor')
      parents[i], encoded[i] = bend_string(parent), json_string(parent)
    end
    local kind = category == 'class' and 'ClassReferenceKind' or 'ModuleReferenceKind'
    return 'Core.NamedReference{Core.' .. kind .. '{}, ' .. bend_string(name) .. ', [' .. table.concat(parents, ', ') .. ']}', '{' .. json_string(category) .. ':' .. json_string(name) .. ',"ancestors":[' .. table.concat(encoded, ',') .. ']}'
  end
  if value.range then
    local range = value.range
    assert(range.first ~= nil and range.last ~= nil and type(range.exclude_end) == 'boolean', 'range needs explicit endpoints and exclusion flag')
    local first, first_json = context_value(range.first)
    local last, last_json = context_value(range.last)
    return 'Core.RangeValue{' .. first .. ', ' .. last .. ', ' .. (range.exclude_end and 'True{}' or 'False{}') .. '}', '{"range":{"first":' .. first_json .. ',"last":' .. last_json .. ',"exclude_end":' .. tostring(range.exclude_end) .. '}}'
  end
  if value.hash then
    local entries, encoded, seen = {}, {}, {}
    for i, pair in ipairs(value.hash) do
      assert(#pair == 2, 'hash entry must contain key and value')
      assert(type(pair[1]) == 'string' or type(pair[1]) == 'table' and (pair[1].symbol or pair[1].class or pair[1].module), 'unsupported hash key')
      local key, key_json = context_value(pair[1])
      assert(not seen[key_json], 'duplicate hash key')
      seen[key_json] = true
      local item, item_json = context_value(pair[2])
      entries[i] = {key, item}
      encoded[i] = '[' .. key_json .. ',' .. item_json .. ']'
    end
    local expression = 'Core.HashNil{}'
    for i = #entries, 1, -1 do expression = 'Core.HashEntry{' .. entries[i][1] .. ', ' .. entries[i][2] .. ', ' .. expression .. '}' end
    return expression, '{"hash":[' .. table.concat(encoded, ',') .. ']}'
  end
  if value.decimal or value.integer then
    local key = value.decimal and 'decimal' or 'integer'
    local text = value[key]
    local literal_text = key == 'integer' and IntegerContext.canonical(text) or text
    local expression = 'Parser.evaluate(' .. bend_string(literal_text) .. ', Nil{}, False{})'
    if key == 'decimal' then
      -- Typed BigDecimal values admit surrounding ASCII whitespace and a +
      -- sign. Keep the original text in the reference payload below.
      local literal = text:gsub('^[\t\n\v\f\r ]+', ''):gsub('[\t\n\v\f\r ]+$', '')
      local negative = literal:sub(1, 1) == '-'
      if negative or literal:sub(1, 1) == '+' then literal = literal:sub(2) end
      assert(not literal:match('^[+-]'), 'invalid typed decimal sign')
      -- Parse the magnitude before applying the sign so integer-looking -0
      -- retains BigDecimal's negative zero.
      expression = 'Core.decimal_result(Parser.evaluate(' .. bend_string(literal) .. ', Nil{}, False{}))'
      if negative then expression = 'Core.negate_value(' .. expression .. ')' end
    end
    return expression, '{' .. json_string(key) .. ':' .. json_string(text) .. '}'
  end
  local expressions, encoded = {}, {}
  for i, item in ipairs(value) do expressions[i], encoded[i] = context_value(item) end
  local expression = 'Core.ArrayNil{}'
  for i = #expressions, 1, -1 do expression = 'Core.ArrayCons{' .. expressions[i] .. ', ' .. expression .. '}' end
  return expression, '[' .. table.concat(encoded, ',') .. ']'
end
local function context_values(context, symbol_context)
  local keys, expressions, encoded = {}, {}, {}
  for name in pairs(context or {}) do keys[#keys+1] = name end
  table.sort(keys)
  for i, name in ipairs(keys) do
    local expression, json = context_value(context[name])
    expressions[i] = 'Core.Bound{' .. bend_string(name) .. ', ' .. expression .. '}'
    encoded[i] = '[{"text":' .. json_string(name) .. '},' .. json .. ']'
  end
  local symbol_keys = {}
  for name in pairs(symbol_context or {}) do symbol_keys[#symbol_keys+1] = name end
  table.sort(symbol_keys)
  for _, name in ipairs(symbol_keys) do
    local expression, json = context_value(symbol_context[name])
    expressions[#expressions+1] = 'Core.SymbolBound{' .. bend_string(name) .. ', ' .. expression .. '}'
    encoded[#encoded+1] = '[{"symbol":' .. json_string(name) .. '},' .. json .. ']'
  end
  -- Ruby stores pairs in insertion order with the last normalized key winning;
  -- Bend's public binding lists put the highest-priority binding first.
  local bindings = {}
  for i = #expressions, 1, -1 do bindings[#bindings+1] = expressions[i] end
  return #bindings == 0 and 'Nil{}' or '[' .. table.concat(bindings, ', ') .. ']', '{"bindings":[' .. table.concat(encoded, ',') .. ']}'
end
local program = not metadata_only and assert(io.open(prefix .. '.bend', 'w'))
local expected = assert(io.open(prefix .. '.expected', 'w'))
local formulas = assert(io.open(prefix .. '.formulas.tsv', 'w'))
if program then program:write('import Base\nimport ../src/core.bend as Core\nimport ../src/parser.bend as Parser\nimport ../src/string.bend as StringOps\n\n') end
if program and gpu then program:write('import ../compat/gpu-corpus.bend as Gpu\n\n') end
if program then
  for _, case in ipairs(cases) do
    if (case.operation or ''):match('calculator_session$') then
      program:write('import ../compat/calculator_api.bend as CalculatorApi\n\n')
      break
    end
  end
end
if program then
  for _, case in ipairs(cases) do
    if (case.operation or ''):match('token_matcher$') then
      program:write('import ../compat/token_matcher_api.bend as MatcherApi\n\n')
      break
    end
  end
end
if program then
  for _, case in ipairs(cases) do
    if (case.operation or ''):match('token$') then
      program:write('import ../compat/token_api.bend as TokenApi\n\n')
      break
    end
  end
end
if program then
  for _, case in ipairs(cases) do
    if (case.operation or ''):match('error_factory$') then
      program:write('import ../compat/error_factory.bend as ErrorFactory\n\n')
      break
    end
  end
end
if program then
  for _, case in ipairs(cases) do
    if (case.operation or ''):match('resolve_') then
      program:write('import ../src/resolver.bend as Resolver\n\n')
      break
    end
  end
end
local ids = {}
local lines = {}
local gpu_inputs = {}
if program and needs_stored then program:write('import ../compat/stored_api.bend as StoredApi\n') end
local gpu_operations = {
  evaluate='Evaluate', permissive='Permissive', identifiers='Identifiers', dependencies='Dependencies',
  class='Class', type='StaticType', message='Message', coerce='Coerce', coerce_class='CoerceClass',
  coerce_message='CoerceMessage', resolve_order='ResolveOrder', resolve_cycles='ResolveCycles', error_factory='DescribeError', token='InspectToken', token_matcher='InspectMatcher', calculator_session='RunCalculator',
}
for _, case in ipairs(cases) do
  assert(not ids[case.id], 'duplicate id: ' .. case.id)
  ids[case.id] = true
  assert(not case.id:find('[\t\r\n]'), 'case IDs cannot contain TSV control characters')
  -- json_ frames snapshots without changing the evaluated operation or value.
  local wire_operation = case.operation or 'evaluate'
  local json_output = wire_operation:sub(1, 5) == 'json_'
  local operation = json_output and wire_operation:sub(6) or wire_operation
  local context, encoded_context = context_values(case.context, case.symbol_context)
  local sensitive = case.sensitive and 'True{}' or 'False{}'
  local call
  if operation == 'stored_value' then
    call = 'StoredApi.snapshot(Core.lookup(' .. context .. ', "input", False{}))'
  elseif operation == 'calculator_session' then
    call = 'CalculatorApi.snapshot(Core.lookup(' .. context .. ', "input", False{}))'
  elseif operation == 'token_matcher' then
    call = 'MatcherApi.snapshot(' .. bend_string(case.formula) .. ', Core.lookup(' .. context .. ', "input", False{}))'
  elseif operation == 'token' then
    call = 'TokenApi.snapshot(' .. bend_string(case.formula) .. ', Core.lookup(' .. context .. ', "input", False{}))'
  elseif operation == 'error_factory' then
    call = 'ErrorFactory.snapshot(' .. bend_string(case.formula) .. ', Core.lookup(' .. context .. ', "input", False{}))'
  elseif operation == 'resolve_order' or operation == 'resolve_cycles' then
    local name = operation == 'resolve_order' and 'order_snapshot' or 'cycles_snapshot'
    call = 'Resolver.' .. name .. '(Core.lookup(' .. context .. ', "input", False{}), ' .. sensitive .. ')'
  elseif operation == 'permissive' then
    call = 'Parser.permissive_snapshot(' .. bend_string(case.formula) .. ', ' .. context .. ', ' .. sensitive .. ')'
  elseif operation == 'identifiers' then
    call = 'Parser.names_snapshot(Parser.identifiers(' .. bend_string(case.formula) .. ', ' .. sensitive .. '))'
  elseif operation == 'dependencies' then
    call = 'Parser.names_snapshot(Parser.dependencies(' .. bend_string(case.formula) .. ', ' .. context .. ', ' .. sensitive .. '))'
  elseif operation == 'class' then
    call = 'Parser.class_snapshot(' .. bend_string(case.formula) .. ', ' .. context .. ', ' .. sensitive .. ')'
  elseif operation == 'type' then
    call = 'Parser.type_snapshot_in(' .. bend_string(case.formula) .. ', ' .. sensitive .. ')'
  elseif operation == 'message' then
    call = 'Parser.message_snapshot(' .. bend_string(case.formula) .. ', ' .. context .. ', ' .. sensitive .. ')'
  elseif operation == 'coerce' or operation == 'coerce_class' or operation == 'coerce_message' then
    local show = operation == 'coerce' and 'snapshot' or operation == 'coerce_class' and 'class_snapshot' or 'message_snapshot'
    call = 'Core.' .. show .. '(Core.require_numeric(Core.lookup(' .. context .. ', "input", ' .. sensitive .. ')))'
  else
    assert(operation == 'evaluate', 'unknown operation: ' .. operation)
    call = 'Parser.snapshot(' .. bend_string(case.formula) .. ', ' .. context .. ', ' .. sensitive .. ')'
  end
  if json_output then call = '"json:" ++ StringOps.json_quote(' .. call .. ')' end
  lines[#lines+1] = '    IO.print(' .. bend_string(case.id .. '\t') .. ' ++ ' .. call .. ')\n'
  if gpu then
    gpu_inputs[#gpu_inputs+1] = 'Gpu.Leaf{Gpu.Check{' .. bend_string(case.id) .. ', ' .. bend_string(case.formula) .. ', Gpu.' .. assert(gpu_operations[operation]) .. '{}, ' .. context .. ', ' .. sensitive .. ', ' .. (json_output and 'True{}' or 'False{}') .. '}}'
  end
  expected:write(case.id, '\t', case.expected, '\n')
  formulas:write(case.id, '\t', json_string(case.formula), '\t', wire_operation, '\t', encoded_context, '\t', tostring(not not case.sensitive), '\tjson\n')
end
-- Keep monadic chains shallow enough for older Bend compiler stacks.
if program and gpu then
  local function tree(first, last)
    if first == last then return gpu_inputs[first] end
    local middle = (first + last) // 2
    return 'Gpu.Fork{' .. tree(first, middle) .. ', ' .. tree(middle + 1, last) .. '}'
  end
  program:write('def main() -> IO(Unit):\n  Gpu.emit(Gpu.evaluate!(', tree(1, #gpu_inputs), '))\n')
  program:close()
elseif program then
  local groups = {}
  for first = 1, #lines, 32 do
    local name = 'corpus_group_' .. (#groups + 1)
    groups[#groups+1] = name
    program:write('def ', name, '() -> IO(Unit):\n  do IO<Unit>:\n')
    for i = first, math.min(first + 31, #lines) do program:write(lines[i]) end
    program:write('\n')
  end
  program:write('def main() -> IO(Unit):\n  do IO<Unit>:\n')
  for _, name in ipairs(groups) do program:write('    ', name, '()\n') end
  program:close()
end
expected:close(); formulas:close()
