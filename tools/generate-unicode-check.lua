local input=assert(arg[1], 'usage: lua tools/generate-unicode-check.lua TABLES.tsv INPUT EXPECTED')
local output=assert(arg[2]); local expected=assert(arg[3])
local ranges={alpha={},word={}}; local maps={lower={},fold={}}; local points={}
local function add(cp)
 if cp>=0 and cp<=0x10ffff and (cp<0xd800 or cp>0xdfff) then points[cp]=true end
end
for cp=0,127 do add(cp) end
for line in io.lines(input) do
 if line:sub(1,1)~='#' then
  local kind,first,last=assert(line:match('^(%w+)\t(%d+)\t([%d,]+)$'));first=tonumber(first)
  if ranges[kind] then
   last=tonumber(last);ranges[kind][#ranges[kind]+1]={first,last}
   for _,cp in ipairs{first-1,first,first+1,last-1,last,last+1} do add(cp) end
  else
   assert(maps[kind]);maps[kind][first]=last
   add(first-1);add(first);add(first+1)
  end
 end
end
local sorted={};for cp in pairs(points) do sorted[#sorted+1]=cp end;table.sort(sorted)
local function member(kind,cp)
 if cp<128 then return cp>=65 and cp<=90 or cp>=97 and cp<=122 or kind=='word' and (cp>=48 and cp<=57 or cp==95) end
 local a,b=1,#ranges[kind]
 while a<=b do local m=(a+b)//2;local r=ranges[kind][m];if cp<r[1] then b=m-1 elseif cp>r[2] then a=m+1 else return true end end
 return false
end
local function mapped(kind,cp)
 if cp>=65 and cp<=90 then return tostring(cp+32) end
 return maps[kind][cp] or tostring(cp)
end
local encoded={};local golden=assert(io.open(expected,'w'))
for _,cp in ipairs(sorted) do
 encoded[#encoded+1]=utf8.char(cp)
 golden:write(cp,'\t',member('alpha',cp) and '1' or '0','\t',member('word',cp) and '1' or '0','\t',mapped('lower',cp),'\t',mapped('fold',cp),'\n')
end
assert(golden:close())
local f=assert(io.open(output,'wb'));f:write('s',#sorted,':',table.concat(encoded),'\n');assert(f:close())
print(#sorted..' Unicode mapping and boundary checks generated')
