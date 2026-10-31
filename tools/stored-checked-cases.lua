local cases={}
for _,case in ipairs(dofile('compat/stored-cases.lua')) do
 cases[#cases+1]={id=case.id:gsub('^stored_value_','stored_checked_'),operation='stored_checked',formula='',context=case.context,expected='pending'}
end
local function S(s) return {symbol=s} end
local function H(t)
 local names={};for k in pairs(t) do names[#names+1]=k end;table.sort(names)
 local items={};for _,k in ipairs(names) do items[#items+1]={S(k),t[k]} end
 return {hash=items}
end
local function P(s,mode) return H{source=s,sensitive=not not mode} end
local function add(id,source,data,programs,message)
 data=data or {};data.__evaluation_mode=S('strict')
 cases[#cases+1]={id='stored_checked_'..id,operation=message and 'stored_checked_message' or 'stored_checked',formula='',context={input=H{source=source,data=H(data),programs=H(programs or {}),receiver_sensitive=false,root_sensitive=false}},expected='pending'}
end
add('preflight_before_zero','1/0+f',{}, {f=P('missing')})
add('sum_preflight_before_zero','SUM(f,g)',{}, {f=P('1/0'),g=P('missing')})
add('unused_missing_after_guard','IF(TRUE,1/0,f)',{}, {f=P('missing')})
add('static_preflight','IF(FALSE,f,42)',{__static_dependencies=true},{f=P('missing')})
add('message_one','f',{}, {f=P('missing')},true)
add('message_duplicate_order','SUM(f,g,f)',{}, {f=P('a+b'),g=P('b+c')},true)
add('message_left_order','g+f',{}, {f=P('a+b'),g=P('b+c')},true)
add('message_guard','IF(flag,1,g)',{}, {flag=P('FALSE'),g=P('missing')},true)
add('message_preflight_zero','1/0+f',{}, {f=P('missing')},true)
add('message_zero_unused_missing','IF(TRUE,1/0,f)',{}, {f=P('missing')},true)
add('message_success','f',{a=2},{f=P('a+1')},true)
add('message_sensitive','f',{a=2},{f=P('A',true)},true)
add('message_null_index','f[missing]',{}, {f=P('NULL')},true)
add('message_sum_duplicates','SUM(f,f)',{}, {f=P('SUM(a,a,b)')},true)
local function literal(v)
 if type(v)=='string' then return string.format('%q',v) end
 if type(v)=='number' or type(v)=='boolean' then return tostring(v) end
 local parts={}
 if #v>0 then for i,x in ipairs(v) do parts[i]=literal(x) end
 else local keys={};for k in pairs(v) do keys[#keys+1]=k end;table.sort(keys);for i,k in ipairs(keys) do parts[i]='['..literal(k)..']='..literal(v[k]) end end
 return '{'..table.concat(parts,',')..'}'
end
local f=assert(io.open(assert(arg[1],'output path required'),'w'));f:write('return {\n');for _,case in ipairs(cases) do f:write(literal(case),',\n') end;f:write('}\n');f:close()
print(#cases..' checked stored-expression probes')
