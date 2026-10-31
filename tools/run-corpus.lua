-- Bound checker memory while retaining every differential case in source order.
local input = assert(arg[1], 'usage: lua tools/run-corpus.lua CASES.lua OUTPUT_PREFIX BEND [BATCH_SIZE [CALCULATOR_BATCH_SIZE [START_INDEX]]]')
local prefix = assert(arg[2], 'missing output prefix')
local bend = assert(arg[3], 'missing Bend executable')
local size = tonumber(arg[4] or '256')
assert(math.type(size) == 'integer' and size > 0, 'invalid batch size')
local calculator_size = tonumber(arg[5] or '8')
assert(math.type(calculator_size) == 'integer' and calculator_size > 0, 'invalid Calculator batch size')
local checker_stack = tonumber(os.getenv('FORMULA_CHECK_STACK_KIB') or '65536')
assert(math.type(checker_stack) == 'integer' and checker_stack > 0, 'invalid checker stack size')
local checker_launcher = [=[
requested="$1"
shift
hard="$(ulimit -Hs)"
case "$hard" in
  unlimited) ;;
  *[!0-9]*|'') ;;
  *) if [ "$hard" -lt "$requested" ]; then requested="$hard"; fi ;;
esac
ulimit -s "$requested" || exit 1
exec "$@"
]=]
print(('Bend checker stack request: %d KiB'):format(checker_stack))
local cases = dofile(input)
assert(#cases > 0, 'empty corpus')
local first = tonumber(arg[6] or '1')
assert(math.type(first) == 'integer' and first >= 1 and first <= #cases, 'invalid start index')
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
local function calculator(index)
  return (cases[index].operation or ''):match('calculator_session$') ~= nil
end
local start = first
while start <= #cases do
  -- Session commands embed complete parser/cache states. Keep those checker
  -- terms in smaller batches without reducing the corpus or mixing boundaries.
  local is_calculator = calculator(start)
  local limit = is_calculator and math.min(size, calculator_size) or size
  local count = 1
  while count < limit and start + count <= #cases and calculator(start + count) == is_calculator do
    count = count + 1
  end
  local part = prefix .. '-part-' .. start
  run({lua, 'tools/generate-corpus.lua', input, part, '--slice', tostring(start), tostring(count)})
  run({'sh', '-c', checker_launcher, 'formula-bend-checker', tostring(checker_stack), bend, part .. '.bend'}, part .. '.actual')
  local file = assert(io.open(part .. '.actual'))
  assert(output:write(file:read('*a')))
  assert(file:close())
  assert(output:flush())
  print(('Checked cases %d–%d of %d'):format(start, start + count - 1, #cases))
  start = start + count
end
assert(output:close())
