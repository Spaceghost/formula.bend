local cases={}
local function S(s)return {symbol=s}end
local function H(t)local k={};for n in pairs(t)do k[#k+1]=n end;table.sort(k);local p={};for i,n in ipairs(k)do p[i]={S(n),t[n]}end;return {hash=p}end
local forms={'IF(f,missing,other)','IF(f,1,2)','IF(TRUE,f,7)','IF(FALSE,f,7)',
 '(f=0) AND missing','(f=0) AND TRUE','TRUE OR (f=0)','FALSE AND IF(f,missing,other)',
 'CASE f WHEN 1 THEN missing ELSE other END','CASE 1 WHEN f THEN missing ELSE other END',
 'CASE 1 WHEN 1 THEN 7 WHEN f THEN missing ELSE other END','SUM(IF(f,missing,other),last)'}
for i,guard in ipairs{'MIN(n,2)','{1}[x]','ROUND(1,p)'}do
 for j,source in ipairs(forms)do
  for _,static in ipairs{false,true}do
   local data={n={float_words={0x7ff80000,1}},x={float_words={0x7ff00000,0}},p={float_words={0x7ff00000,0}},__evaluation_mode=S('strict')}
   if static then data.__static_dependencies=true end
   local input=H{source=source,data=H(data),programs=H{f=H{source=guard,sensitive=false}},receiver_sensitive=false}
   for _,operation in ipairs{'stored_checked','stored_checked_message','stored_dependencies'}do
    cases[#cases+1]={id=('stored_native_%d_%d_%s_%s'):format(i,j,tostring(static),operation),operation=operation,formula='',context={input=input},expected='pending'}
   end
  end
 end
end
local function literal(v)
 if type(v)=='string'then return string.format('%q',v)end;if type(v)=='number'or type(v)=='boolean'then return tostring(v)end
 local p={};if #v>0 then for i,x in ipairs(v)do p[i]=literal(x)end else local k={};for x in pairs(v)do k[#k+1]=x end;table.sort(k);for i,x in ipairs(k)do p[i]='['..literal(x)..']='..literal(v[x])end end;return '{'..table.concat(p,',')..'}'
end
local f=assert(io.open(assert(arg[1],'output path required'),'w'));f:write('return {\n');for _,c in ipairs(cases)do f:write(literal(c),',\n')end;f:write('}\n');f:close()
print(#cases..' stored native-error probes generated')
