local cases={}
local function S(s) return {symbol=s} end
local function H(t)
 local names={};for k in pairs(t) do names[#names+1]=k end;table.sort(names)
 local items={};for _,k in ipairs(names) do items[#items+1]={S(k),t[k]} end
 return {hash=items}
end
local function C(op,t) t=t or {};t.op=op;return H(t) end
local expressions={
 'a+a+b','SUM(a,a,b)','IF(flag,a,b)','IF(TRUE,a,b)',
 'IF(FALSE,a,b)','a AND b','a OR b',
 'MAP(items,x,x+a)','REDUCE(items,m,x,m+x+a,seed)',
 'CASE flag WHEN TRUE THEN a ELSE b END',
 'b.c+a','missing[0]','IF(1/0,a,b)','a+','@',
 {'a','b','a','SUM(a,a,b)'},H{first='a+a',second={'b','a'}},
 {},H{},'A+a','Äpfel+äpfel',
 'a@b','a&&b','a||b','a && b','a || b','"unterminated',
}
for _,sensitive in ipairs{false,true} do
 for _,cached in ipairs{false,true} do
  for i,expression in ipairs(expressions) do
   local commands={
    C('store',{values=H{a=3,flag=true,items={1,2},b=H{c=7}}}),
    C('dependencies',{expression=expression}),
    C('dependencies',{expression=expression,data=H{flag=false,a=9,seed=0}}),
    C('dependencies_nil',{expression=expression}),
    C('dependencies',{expression=expression,data=H{__static_dependencies=true}}),
    C('dependencies',{expression=expression,data=H{__static_dependencies=1}}),
    C('identifiers',{expression=expression}),
    C('memory'),C('cache_keys'),
   }
   cases[#cases+1]={id='calculator_dependencies_'..(sensitive and 'sensitive' or 'folded')..'_'..(cached and 'cached' or 'uncached')..'_'..i,operation='calculator_session',formula='',context={input=H{options=H{case_sensitive=sensitive,cache_ast=cached},commands=commands}},expected='pending'}
  end
 end
end
for _,origin in ipairs{false,true} do
 for _,receiver in ipairs{false,true} do
  cases[#cases+1]={id='calculator_dependencies_transfer_'..tostring(origin)..'_'..tostring(receiver),operation='calculator_session',formula='',context={input=H{options=H{case_sensitive=receiver,cache_ast=true},commands={
   C('store',{values=H{A=3}}),
   C('warm_cache_from',{source_sensitive=origin,entries=H{probe='A+a'}}),
   C('dependencies',{expression='probe'}),
   C('dependencies_nil',{expression='probe'}),
   C('identifiers',{expression={'probe','probe'}}),
   C('memory'),C('cache_keys'),
  }}},expected='pending'}
 end
end
local function literal(v)
 if type(v)=='string' then return string.format('%q',v) end
 if type(v)=='number' or type(v)=='boolean' then return tostring(v) end
 local parts={}
 if #v>0 then for i,x in ipairs(v) do parts[i]=literal(x) end
 else local keys={};for k in pairs(v) do keys[#keys+1]=k end;table.sort(keys);for i,k in ipairs(keys) do parts[i]='['..literal(k)..']='..literal(v[k]) end end
 return '{'..table.concat(parts,',')..'}'
end
local f=assert(io.open(assert(arg[1],'output path required'),'w'));f:write('return {\n');for _,case in ipairs(cases) do f:write(literal(case),',\n') end;f:write('}\n');f:close()
print(#cases..' Calculator dependency/identifier sessions')
