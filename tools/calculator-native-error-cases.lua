local cases={}
local function S(s)return {symbol=s}end
local function H(t)local k={};for n in pairs(t)do k[#k+1]=n end;table.sort(k);local p={};for i,n in ipairs(k)do p[i]={S(n),t[n]}end;return {hash=p}end
local function C(op,t)t=t or {};t.op=op;return H(t)end
local bad={'{1}[x]','MIN(n,2)','ROUND(1,p)'}
for _,cached in ipairs{false,true}do
 for _,strict in ipairs{false,true}do
  for i,formula in ipairs(bad)do
   local shapes={formula,{formula,'a+1'},{'a+1',formula,'a+2'},H{first=formula,second='a+1'},{{formula,'a+1'},'a+2'}}
   for j,expression in ipairs(shapes)do
    local data=H{x={float_words={0x7ff00000,0}},n={float_words={0x7ff80000,1}},p={float_words={0x7ff00000,0}},a=9}
    cases[#cases+1]={id=('calculator_native_%s_%s_%d_%d'):format(tostring(cached),tostring(strict),i,j),operation='calculator_session',formula='',context={input=H{options=H{cache_ast=cached},commands={C('store',{values=H{a=4}}),C(strict and 'evaluate!' or 'evaluate',{expression=expression,data=data}),C('memory'),C('cache_keys'),C('evaluate!',{expression='a+10'}),C('memory')}}},expected='pending'}
   end
  end
 end
end
local function literal(v)
 if type(v)=='string'then return string.format('%q',v)end;if type(v)=='number'or type(v)=='boolean'then return tostring(v)end
 local p={};if #v>0 then for i,x in ipairs(v)do p[i]=literal(x)end else local k={};for x in pairs(v)do k[#k+1]=x end;table.sort(k);for i,x in ipairs(k)do p[i]='['..literal(x)..']='..literal(v[x])end end;return '{'..table.concat(p,',')..'}'
end
local f=assert(io.open(assert(arg[1],'output path required'),'w'));f:write('return {\n');for _,c in ipairs(cases)do f:write(literal(c),',\n')end;f:write('}\n');f:close()
print(#cases..' Calculator native-error sessions generated')
