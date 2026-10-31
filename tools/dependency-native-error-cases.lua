local cases={}
local guards={'MIN(n,2)','{1}[x]','ROUND(1,p)'}
local templates={
 'IF(G,missing,other)','IF(G,1,2)','IF(TRUE,IF(G,missing,other),7)',
 'IF(FALSE,IF(G,missing,other),7)','IF(TRUE,7,IF(G,missing,other))',
 '(G=0) AND missing','missing AND (G=0)','(G=0) OR missing','missing OR (G=0)',
 '(G=0) AND TRUE','TRUE OR (G=0)','FALSE AND (G=0)','(G=0) OR TRUE',
 'TRUE OR IF(G,missing,other)','FALSE AND IF(G,missing,other)',
 'CASE G WHEN 1 THEN missing ELSE other END',
 'CASE 1 WHEN G THEN missing ELSE other END',
 'CASE 1 WHEN 1 THEN 7 WHEN G THEN missing ELSE other END',
 'CASE 1 WHEN 2 THEN missing WHEN G THEN 7 ELSE other END',
 'SUM(IF(G,missing,other),last)','SUM(first,IF(G,missing,other))',
 '{IF(G,missing,other),last}','IF(G,missing,other)[last]',
 'IF(1/0,IF(G,missing,other),last)','IF(G,1,2)+IF({1}[x],3,4)',
}
for g,guard in ipairs(guards)do
 for j,template in ipairs(templates)do
  local formula=template:gsub('G',function()return guard end)
  for marker=1,3 do
   local context={n={float_words={0x7ff80000,1}},x={float_words={0x7ff00000,0}},p={float_words={0x7ff00000,0}}}
   if marker==2 then context.__static_dependencies=true elseif marker==3 then context.__static_dependencies=1 end
   for _,operation in ipairs{'evaluate','permissive','class','message','dependencies','identifiers'}do
    cases[#cases+1]={id=('dependency_native_%d_%d_%d_%s'):format(g,j,marker,operation),formula=formula,context=context,operation=operation,expected='pending'}
   end
  end
 end
end
local function S(s)return {symbol=s}end
local function H(t)local k={};for n in pairs(t)do k[#k+1]=n end;table.sort(k);local p={};for i,n in ipairs(k)do p[i]={S(n),t[n]}end;return {hash=p}end
local function C(op,t)t=t or {};t.op=op;return H(t)end
for i,guard in ipairs(guards)do
 for j,template in ipairs{'IF(G,missing,other)','(G=0) AND missing','CASE G WHEN 1 THEN missing ELSE other END','TRUE OR IF(G,missing,other)'}do
  local formula=template:gsub('G',function()return guard end)
  for _,cached in ipairs{false,true}do
   for k,expression in ipairs{formula,{formula,'a'},H{first=formula,second='a'},{{formula},'a'}}do
    local data={n={float_words={0x7ff80000,1}},x={float_words={0x7ff00000,0}},p={float_words={0x7ff00000,0}}}
    local ordinary=H(data);data.__static_dependencies=true;local static=H(data)
    cases[#cases+1]={id=('dependency_native_calculator_%d_%d_%s_%d'):format(i,j,tostring(cached),k),operation='calculator_session',formula='',context={input=H{options=H{cache_ast=cached},commands={
     C('store',{values=H{a=4}}),C('dependencies',{expression=expression,data=ordinary}),
     C('dependencies_nil',{expression=expression}),C('dependencies',{expression=expression,data=static}),
     C('identifiers',{expression=expression}),C('memory'),C('cache_keys'),
    }}},expected='pending'}
   end
  end
 end
end
local function literal(v)
 if type(v)=='string'then return string.format('%q',v)end;if type(v)=='number'or type(v)=='boolean'then return tostring(v)end
 local p={};if #v>0 then for i,x in ipairs(v)do p[i]=literal(x)end else local k={};for x in pairs(v)do k[#k+1]=x end;table.sort(k);for i,x in ipairs(k)do p[i]='['..literal(x)..']='..literal(v[x])end end;return '{'..table.concat(p,',')..'}'
end
local f=assert(io.open(assert(arg[1],'output path required'),'w'));f:write('return {\n');for _,c in ipairs(cases)do f:write(literal(c),',\n')end;f:write('}\n');f:close()
print(#cases..' native dependency guard probes generated')
