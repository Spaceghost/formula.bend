local output = assert(arg[1], 'usage: lua tools/generate-binary64-ruby-conversion-cases.lua OUTPUT [smoke|full]')
local profile = arg[2] or 'full'
assert(profile == 'smoke' or profile == 'full', 'unknown profile')
local original = arg
arg = {output..'.ieee-source', profile}
dofile('tools/generate-binary64-conversion-cases.lua')
arg = original
local rows = {}
for line in io.lines(output..'.ieee-source') do
  if line:find(' from_decimal ', 1, true) then rows[#rows+1] = (line:gsub(' from_decimal ', ' from_ruby_decimal ', 1)) end
end
-- Cutoff positions, delayed nonzero digits, and normalized integer zeros.
local prefixes = {
  '1'..string.rep('0',59), string.rep('9',60),
  '123456789012345678901234567890123456789012345678901234567890',
}
local id = 0
for _,prefix in ipairs(prefixes) do
  for _,zeros in ipairs{0,1,2,60,1200} do
    for _,tail in ipairs{'0','1','5','9'} do
      local digits = prefix..string.rep('0',zeros)..tail..'123456789'
      for _,exponent in ipairs{-325,-324,-308,-1,0,15,308,309} do
        for _,sign in ipairs{'+','-'} do
          id = id + 1
          local scale = #digits - 1 - exponent
          local coefficient = digits
          if scale < 0 then coefficient,scale = coefficient..string.rep('0',-scale),0 end
          rows[#rows+1] = ('ruby_decimal_cutoff_%d from_ruby_decimal %s %s %d'):format(id,sign,coefficient,scale)
        end
      end
    end
  end
end
local f = assert(io.open(output,'w'))
assert(f:write(table.concat(rows,'\n')..'\n')); assert(f:close())
print(#rows .. ' pinned Ruby BigDecimal-to-Float probes generated ('..profile..')')
