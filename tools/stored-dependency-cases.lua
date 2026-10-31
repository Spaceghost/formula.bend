local cases={}
for _,case in ipairs(dofile('compat/stored-cases.lua')) do
 cases[#cases+1]={id=case.id:gsub('^stored_value_','stored_dependencies_'),operation='stored_dependencies',formula='',context=case.context,expected='pending'}
end
local function S(s) return {symbol=s} end
local function H(t)
 local names={};for k in pairs(t) do names[#names+1]=k end;table.sort(names)
 local items={};for _,k in ipairs(names) do items[#items+1]={S(k),t[k]} end
 return {hash=items}
end
local function P(s,mode) return H{source=s,sensitive=not not mode} end
local function add(id,source,data,programs)
 data=data or {};data.__evaluation_mode=S('strict')
 cases[#cases+1]={id='stored_dependencies_'..id,operation='stored_dependencies',formula='',context={input=H{source=source,data=H(data),programs=H(programs or {}),receiver_sensitive=false,root_sensitive=false}},expected='pending'}
end
add('sum_duplicates','SUM(f,f)',{}, {f=P('missing+other')})
add('add_unique','f+f',{}, {f=P('missing+other')})
add('guard_false','IF(flag,f,other)',{}, {flag=P('FALSE'),f=P('missing')})
add('guard_true','IF(flag,f,other)',{}, {flag=P('TRUE'),f=P('missing')})
add('guard_missing','IF(flag,f,other)',{}, {flag=P('unknown_guard'),f=P('missing')})
add('and_false','flag AND f',{}, {flag=P('FALSE'),f=P('missing')})
add('or_true','flag OR f',{}, {flag=P('TRUE'),f=P('missing')})
add('case_stored_subject','CASE flag WHEN 2 THEN f ELSE other END',{}, {flag=P('2'),f=P('missing')})
add('case_stored_key','CASE 2 WHEN key THEN f ELSE other END',{}, {key=P('2'),f=P('missing')})
add('map_outer','MAP(items,x,f)',{items={1,2}},{f=P('x+outer')})
add('map_nested_field','MAP(items,x,f)',{items={H{score=2}}},{f=P('x.score+outer')})
add('reduce_outer','REDUCE(items,m,x,f,0)',{items={1,2}},{f=P('m+x+outer')})
add('map_origin_sensitive','MAP(items,x,f)',{items={1,2}},{f=P('X+outer',true)})
add('transitive_missing','g',{}, {f=P('a+b'),g=P('f+c')})
add('static_guard','IF(flag,f,other)',{__static_dependencies=true},{flag=P('FALSE'),f=P('missing')})
add('static_bound','IF(flag,f,other)',{__static_dependencies=true,missing=1,other=2},{flag=P('FALSE'),f=P('missing')})
add('truthy_marker','IF(flag,f,other)',{__static_dependencies=1},{flag=P('FALSE'),f=P('missing')})
local function literal(v)
 if type(v)=='string' then return string.format('%q',v) end
 if type(v)=='number' or type(v)=='boolean' then return tostring(v) end
 local parts={}
 if #v>0 then for i,x in ipairs(v) do parts[i]=literal(x) end
 else local keys={};for k in pairs(v) do keys[#keys+1]=k end;table.sort(keys);for i,k in ipairs(keys) do parts[i]='['..literal(k)..']='..literal(v[k]) end end
 return '{'..table.concat(parts,',')..'}'
end
local f=assert(io.open(assert(arg[1],'output path required'),'w'));f:write('return {\n');for _,case in ipairs(cases) do f:write(literal(case),',\n') end;f:write('}\n');f:close()
print(#cases..' stored AST dependency probes')
