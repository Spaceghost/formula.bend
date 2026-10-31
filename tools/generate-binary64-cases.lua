-- Raw words avoid passing reference Floats through Lua/JSON number conversion.
local output = assert(arg[1], 'usage: lua tools/generate-binary64-cases.lua OUTPUT [smoke|full]')
local profile = arg[2] or 'full'
assert(profile == 'smoke' or profile == 'full', 'unknown binary64 profile')
local values = {
  {0,0}, {0x80000000,0}, {0x3ff00000,0}, {0xbff00000,0},
  {0x40000000,0}, {0x3fe00000,0}, {0x3ff00000,1}, {0x3ca00000,0},
  {0,1}, {0x000fffff,0xffffffff}, {0x00100000,0}, {0x00100000,1},
  {0x3fefffff,0xffffffff}, {0x3fb99999,0x9999999a}, {0x40080000,0},
  {0x7fefffff,0xffffffff}, {0x7ff00000,0}, {0xfff00000,0},
  {0x7ff80000,1}, {0x7ff00000,1}, {0xfff80000,0},
  {0x80000000,1}, {0x800fffff,0xffffffff}, {0x80100000,0},
  {0x3cb00000,0}, {0x3fd00000,0}, {0x7fdfffff,0xffffffff},
}
if profile == 'smoke' then while #values > 8 do values[#values] = nil end end
local f = assert(io.open(output, 'w'))
local count = 0
local function add(id, op, a, b)
  count = count + 1
  assert(f:write(('%s %s %u %u %u %u\n'):format(id, op, a[1], a[2], b[1], b[2])))
end
for i,a in ipairs(values) do
  add('binary64_roundtrip_'..i, 'roundtrip', a, values[1])
  add('binary64_words_'..i, 'words', a, values[1])
  for j,b in ipairs(values) do
    for _,op in ipairs{'add','subtract','multiply','divide','compare'} do
      add(('binary64_named_%d_%d_%s'):format(i,j,op), op, a, b)
    end
  end
end
local seed = 0x6d2b79f5
local function next_word()
  seed = (seed ~ (seed << 13)) & 0xffffffff
  seed = (seed ~ (seed >> 17)) & 0xffffffff
  seed = (seed ~ (seed << 5)) & 0xffffffff
  return seed
end
for i=1,(profile == 'full' and 128 or 4) do
  local a,b = {next_word(),next_word()}, {next_word(),next_word()}
  add('binary64_random_roundtrip_'..i, 'roundtrip', a, values[1])
  add('binary64_random_words_'..i, 'words', a, values[1])
  for _,op in ipairs{'add','subtract','multiply','divide','compare'} do
    add(('binary64_random_%d_%s'):format(i,op), op, a, b)
  end
end
assert(f:close())
print(count .. ' binary64 arithmetic/roundtrip cases generated (' .. profile .. ')')
