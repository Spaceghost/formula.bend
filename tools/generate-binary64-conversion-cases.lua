local output = assert(arg[1], 'usage: lua tools/generate-binary64-conversion-cases.lua OUTPUT [smoke|full]')
local profile = arg[2] or 'full'
assert(profile == 'smoke' or profile == 'full', 'unknown conversion profile')
local f = assert(io.open(output, 'w'))
local count = 0
local function row(id, op, a)
  count = count + 1
  assert(f:write(('%s %s %u %u 0 0\n'):format(id,op,a[1],a[2])))
end
local function decimal(id, negative, coefficient, scale)
  count = count + 1
  assert(f:write(('%s from_decimal %s %s %d\n'):format(id,negative and '-' or '+',coefficient,scale)))
end
local values = {
  {0,0}, {0x80000000,0}, {0x3ff00000,0}, {0xbff00000,0},
  {0x3fb99999,0x9999999a}, {0,1}, {0x000fffff,0xffffffff},
  {0x00100000,0}, {0x00100000,1}, {0x7fefffff,0xffffffff},
  {0x7ff00000,0}, {0xfff00000,0}, {0x7ff80000,1}, {0xfff00000,1},
  {0x3fefffff,0xffffffff}, {0x3ff00000,1}, {0x80000000,1},
}
if profile == 'smoke' then while #values > 6 do values[#values] = nil end end
local seed = 0x4c957f2d
local function next_word()
  seed = (seed ~ (seed << 13)) & 0xffffffff
  seed = (seed ~ (seed >> 17)) & 0xffffffff
  seed = (seed ~ (seed << 5)) & 0xffffffff
  return seed
end
if profile == 'full' then
  for _=1,64 do values[#values+1] = {next_word(),next_word()} end
end
for i,a in ipairs(values) do
  row('binary64_exact_'..i, 'to_exact', a)
  row('binary64_exact_roundtrip_'..i, 'exact_roundtrip', a)
end
local coefficients = {'0','1','2','3','5','10','9007199254740991','9007199254740992','9007199254740993','9007199254740995','18446744073709551615'}
local scales = profile == 'smoke' and {0,1,324} or {0,1,16,324,1075,281474976710655}
if profile == 'smoke' then while #coefficients > 6 do coefficients[#coefficients] = nil end end
for i,c in ipairs(coefficients) do
  for _,scale in ipairs(scales) do
    for _,negative in ipairs{false,true} do
      decimal(('binary64_decimal_%d_%d_%s'):format(i,scale,tostring(negative)),negative,c,scale)
    end
  end
end
local function multiply_small(text, factor)
  local out,carry = {},0
  for i=#text,1,-1 do
    local n = (text:byte(i)-48)*factor+carry
    out[#out+1],carry = tostring(n%10),n//10
  end
  while carry > 0 do out[#out+1],carry = tostring(carry%10),carry//10 end
  for i=1,#out//2 do out[i],out[#out-i+1] = out[#out-i+1],out[i] end
  return table.concat(out)
end
local function power(base, exponent)
  local result='1'; for _=1,exponent do result=multiply_small(result,base) end; return result
end
local function increment(text, direction)
  local out,carry = {},direction
  for i=#text,1,-1 do
    local n=text:byte(i)-48+carry
    if n<0 then n,carry=n+10,-1 elseif n>9 then n,carry=n-10,1 else carry=0 end
    out[#out+1]=tostring(n)
  end
  assert(carry>=0, 'negative fixture coefficient')
  if carry>0 then out[#out+1]=tostring(carry) end
  for i=1,#out//2 do out[i],out[#out-i+1] = out[#out-i+1],out[i] end
  return table.concat(out):gsub('^0+(%d)','%1')
end
if profile == 'full' then
  -- Exact midpoints at 1+2^-53, the underflow edge, and the overflow edge.
  local half_ulp = power(5,53)
  half_ulp = string.rep('0',53-#half_ulp)..half_ulp
  local one_midpoint = '1'..half_ulp
  local underflow_midpoint = power(5,1075)
  local overflow_midpoint
  local high,low = power(2,1024),power(2,970)
  -- Subtract positive decimal integers without using Lua floating point.
  local digits,borrow = {},0
  low=string.rep('0',#high-#low)..low
  for i=#high,1,-1 do
    local n=high:byte(i)-low:byte(i)-borrow
    if n<0 then n,borrow=n+10,1 else borrow=0 end
    digits[#digits+1]=tostring(n)
  end
  assert(borrow==0)
  for i=1,#digits//2 do digits[i],digits[#digits-i+1]=digits[#digits-i+1],digits[i] end
  overflow_midpoint=table.concat(digits):gsub('^0+','')
  local midpoints={{one_midpoint,53},{underflow_midpoint,1075},{overflow_midpoint,0}}
  for _,k in ipairs{3,5,7,4503599627370495,9007199254740991} do
    midpoints[#midpoints+1]={multiply_small(underflow_midpoint,k),1075}
  end
  for i,pair in ipairs(midpoints) do
    for _,extra in ipairs{0,1200,10000} do
      local center=pair[1]..string.rep('0',extra)
      for _,offset in ipairs{-1,0,1} do
        for _,negative in ipairs{false,true} do
          decimal(('binary64_midpoint_%d_%d_%d_%s'):format(i,extra,offset,tostring(negative)),negative,increment(center,offset),pair[2]+extra)
        end
      end
    end
  end
  decimal('binary64_long_near_one',false,'1'..string.rep('0',10000)..'1',10001)
  decimal('binary64_long_nines',false,string.rep('9',10000),10000)
  decimal('binary64_long_overflow',false,string.rep('9',10000),0)
end
assert(f:close())
print(count..' exact-decimal/binary64 conversion probes generated ('..profile..')')
