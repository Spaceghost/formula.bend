local input = assert(arg[1], 'usage: lua tools/generate-corpus.lua CASES.lua OUTPUT_PREFIX')
local prefix = assert(arg[2], 'missing output prefix')
local cases = dofile(input)
local function bend_string(s)
  return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
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
  program:write('    IO.print(', bend_string(case.id .. '\t'), ' ++ Parser.snapshot(', bend_string(case.formula), ', Nil{}, False{}))\n')
  expected:write(case.id, '\t', case.expected, '\n')
  formulas:write(case.id, '\t', case.formula, '\n')
end
program:close(); expected:close(); formulas:close()
