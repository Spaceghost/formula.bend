-- Raw binary64 words: Ruby supplies the formatting reference independently.
local output = assert(arg[1], 'usage: lua tools/generate-binary64-format-cases.lua OUTPUT [smoke|full]')
local profile = arg[2] or 'full'
assert(profile == 'smoke' or profile == 'full', 'unknown profile')
local f = assert(io.open(output, 'w'))
local count, seen = 0, {}
local function add(high, low)
  local key = ('%u:%u'):format(high, low)
  if seen[key] then return end
  seen[key], count = true, count + 1
  assert(f:write(('binary64_format_%d format %u %u 0 0\n'):format(count, high, low)))
end
for _,v in ipairs{
  {0,0},{0x80000000,0},{0,1},{0,2},{0,3},{0x80000000,1},
  {0x000fffff,0xffffffff},{0x00100000,0},{0x00100000,1},
  {0x3fefffff,0xffffffff},{0x3ff00000,0},{0x3ff00000,1},
  {0x3fb99999,0x9999999a},{0x7fefffff,0xffffffff},{0xffefffff,0xffffffff},
  {0x7ff00000,0},{0xfff00000,0},{0x7ff80000,1},{0xfff00000,1},
  {1058682594,3944497965},{1055193269,2296604913},
  {1121369284,512753664},{1124887541,640942080},{1124887541,640942088},
} do add(v[1],v[2]) end
if profile == 'full' then
  -- All exponent bins, both parity classes, and both sides of powers of two.
  for exponent = 1,2046 do
    local high = exponent << 20
    add(high, 0)
    add(high, 1)
    add(high-1, 0xffffffff)
  end
  local seed = 0xd70a19e3
  local function word()
    seed = (seed ~ (seed << 13)) & 0xffffffff
    seed = (seed ~ (seed >> 17)) & 0xffffffff
    seed = (seed ~ (seed << 5)) & 0xffffffff
    return seed
  end
  for i = 1,512 do add(word(), word()) end
end
assert(f:close())
print(count .. ' binary64 formatting probes generated (' .. profile .. ')')
