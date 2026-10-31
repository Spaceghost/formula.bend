local output = assert(arg[1], 'usage: lua tools/generate-binary64-coercion-cases.lua OUTPUT [smoke|full]')
local profile = arg[2] or 'full'
assert(profile == 'smoke' or profile == 'full', 'unknown profile')
local original = arg
arg = {output..'.arithmetic-source', profile}
dofile('tools/generate-binary64-cases.lua')
arg = original
local f = assert(io.open(output, 'w'))
local count = 0
for line in io.lines(output..'.arithmetic-source') do
  local id,high,low = line:match('^(%S+)%s+roundtrip%s+(%d+)%s+(%d+)')
  if id then
    for _,op in ipairs{'bigdecimal_implicit','bigdecimal_text'} do
      assert(f:write(('%s_%s %s %s %s 0 0\n'):format(id,op,op,high,low)))
      count = count + 1
    end
  end
end
assert(f:close())
print(count .. ' pinned Ruby Float-to-BigDecimal coercion probes generated ('..profile..')')
