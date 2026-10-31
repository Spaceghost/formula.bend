-- Exact source examples plus the parameterized function-name constructor.
local cases={}
local null={null=true}
local function S(s) return {symbol=s} end
local function H(t)
 local names={};for name in pairs(t) do names[#names+1]=name end;table.sort(names)
 local pairs={};for _,name in ipairs(names) do pairs[#pairs+1]={S(name),t[name]} end
 return {hash=pairs}
end
local function T(category,value) return H{category=S(category),value=value} end
local function add(id,operation,input)
 cases[#cases+1]={id='matcher_upstream_'..id,operation='token_matcher',formula=operation,context={input=H(input)},expected='pending'}
end
local function accept(id,matcher,token) add(id,'accept',{matcher=matcher,token=token}) end
local numeric=T('numeric',5)
accept('single_category',H{categories=S('numeric')},numeric)
for i,token in ipairs{T('comparator',S('lt')),T('operator',S('add')),numeric} do
 accept('multiple_categories_'..i,H{categories={S('comparator'),S('operator')}},token)
end
for i,token in ipairs{T('operator',S('add')),T('operator',S('subtract'))} do
 accept('single_value_'..i,H{categories=S('operator'),values=S('add')},token)
end
local operators={'add','subtract','multiply','divide'}
for i,name in ipairs(operators) do
 accept('multiple_values_'..i,H{categories=S('operator'),values={S('add'),S('subtract')}},T('operator',S(name)))
end
for i,token in ipairs{T('operator',S('add')),T('operator',S('multiply')),T('comparator',S('lt'))} do
 accept('invert_'..i,H{categories=S('operator'),values={S('add'),S('subtract')},modifiers={'invert'}},token)
end
for i,token in ipairs{numeric,T('string','rhubarb')} do
 accept('either_'..i,H{categories=S('numeric'),alternatives={H{categories=S('string')}}},token)
end
for i,token in ipairs{T('numeric',8),T('string','apricot'),T('logical',false),T('function',S('round')),T('identifier',S('hello'))} do
 accept('value_'..i,H{builtin='value'},token)
end
local stream={T('numeric',5),T('numeric',11),T('numeric',9),T('numeric',24),T('identifier',S('hello')),T('numeric',8)}
for _,quantifier in ipairs{'standard','star','plus'} do
 local modifiers=quantifier=='standard' and {} or {quantifier}
 for _,offset in ipairs{0,4} do
  add('stream_'..quantifier..'_'..offset,'match',{matcher=H{categories=S('numeric'),modifiers=modifiers},stream=stream,offset=offset})
 end
end
-- spec_helper.type_for(:'(') is :identifier, not :grouping.
add('arguments','match',{matcher=H{builtin='arguments'},stream={
 T('numeric',1),T('grouping',S('comma')),T('numeric',2),T('grouping',S('comma')),
 T('logical',true),T('grouping',S('comma')),T('string','olive'),T('grouping',S('comma')),T('identifier',S('('))}})
local names={null,S('round'),'round',S('arbitrary'),'',S('λ'),false,1,{decimal='1'},{S('round'),S('not')},{{S('round'),null}},{hash={{S('name'),'round'}}}}
for i,name in ipairs(names) do
 local matcher=H{builtin='function',values=name}
 add('function_'..i..'_describe','describe',{matcher=matcher})
 for j,value in ipairs(names) do accept('function_'..i..'_value_'..j,matcher,T('function',value)) end
end
local function literal(value)
 if type(value)=='string' then return string.format('%q',value) end
 if type(value)=='number' or type(value)=='boolean' then return tostring(value) end
 local parts={}
 if #value>0 then for i,v in ipairs(value) do parts[i]=literal(v) end
 else local keys={};for k in pairs(value) do keys[#keys+1]=k end;table.sort(keys);for i,k in ipairs(keys) do parts[i]='['..literal(k)..']='..literal(value[k]) end end
 return '{'..table.concat(parts,',')..'}'
end
local f=assert(io.open(assert(arg[1],'output path required'),'w'));f:write('return {\n');for _,case in ipairs(cases) do f:write(literal(case),',\n') end;f:write('}\n');f:close()
print(#cases..' exact scenario and function-constructor probes')
