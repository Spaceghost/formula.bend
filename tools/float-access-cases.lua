-- Exact Ruby Float inputs; avoid probes that request enormous allocations.
local cases={}
local words={
 {0,0},{0x80000000,0},{0x3ff00000,1},{0x3ffccccd,0},{0xbffccccd,0},
 {0x400c0000,0},{0xc00c0000,0},{0,1},{0x43400000,0},
 {0x7fefffff,0xffffffff},{0x7ff00000,0},{0xfff00000,0},{0x7ff80000,1},
 {0x43dfffff,0xffffffff},{0x43e00000,0},{0xc3e00000,0},
 {0xc3e00000,1},{0x43e00000,1},{0x4415af1d,0x78b58c40},
 {0xfff80000,1},{0xffefffff,0xffffffff},
}
local function add(i,j,formula,operation)
 cases[#cases+1]={id=('float_access_%d_%d_%s'):format(i,j,operation or 'value'),formula=formula,operation=operation,context={x={float_words=words[i]}},expected='pending'}
end
local formulas={'{10,20,30}[x]','"abc"[x]','1 & x','1 | x','8 << x','8 >> x','x & 1','x | 1','x << 1','x >> 1','CONCAT(x)','LEN(x)','{1,2}*x'}
for i in ipairs(words) do
 for j,s in ipairs(formulas) do
  -- Only small finite counts, or non-finite counts rejected before allocation.
  local growth=(j==5 or j==6 or j==13)
  if not growth or i<=8 or i==11 or i==12 or i==13 or i==20 then
   add(i,j,s)
   if j<=10 or j==13 then add(i,j,s,'message') end
  end
 end
end
local function literal(v)
 if type(v)=='string' then return string.format('%q',v) end
 if type(v)=='number' or type(v)=='boolean' then return tostring(v) end
 local p={};if #v>0 then for i,x in ipairs(v) do p[i]=literal(x) end else local k={};for x in pairs(v) do k[#k+1]=x end;table.sort(k);for i,x in ipairs(k) do p[i]='['..literal(x)..']='..literal(v[x]) end end;return '{'..table.concat(p,',')..'}'
end
local f=assert(io.open(assert(arg[1],'output path required'),'w'));f:write('return {\n');for _,c in ipairs(cases) do f:write(literal(c),',\n') end;f:write('}\n');f:close()
print(#cases..' Float indexing, bitwise and repetition probes generated')
