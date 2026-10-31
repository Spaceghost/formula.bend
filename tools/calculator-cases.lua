local cases={}
local function S(s) return {symbol=s} end
local function H(t)
 local names={};for name in pairs(t) do names[#names+1]=name end;table.sort(names)
 local pairs={};for _,name in ipairs(names) do pairs[#pairs+1]={S(name),t[name]} end
 return {hash=pairs}
end
local function cmd(op,t) t=t or {};t.op=op;return H(t) end
local function E(expr,data,strict) return cmd(strict and 'evaluate!' or 'evaluate',{expression=expr,data=data or H{}}) end
local function add(id,commands,options)
 cases[#cases+1]={id='calculator_'..id,operation='calculator_session',formula='',context={input=H{options=H(options or {}),commands=commands}},expected='pending'}
end
add('empty',{cmd('empty'),cmd('memory'),cmd('cache_keys'),cmd('cache_enabled')})
add('discard_locals',{E('pears * 2',H{pears=5}),cmd('empty'),cmd('memory')})
add('store_false',{cmd('store_pair',{key='i_am_false',value=false}),E('i_am_false',nil,true)})
add('store_multiple',{cmd('store',{values=H{first=1,second=2}}),E('first',nil,true),E('second',nil,true),cmd('clear'),cmd('empty')})
for _,sensitive in ipairs{false,true} do
 for _,nested in ipairs{false,true} do
  local label=(sensitive and 'sensitive' or 'folded')..'_'..(nested and 'nested' or 'flat')
  local options={case_sensitive=sensitive,nested_data_support=nested,cache_ast=true}
  add(label..'_keys',{
   cmd('store',{values={hash={{S('Apples'),1},{S('apples'),2},{'APPLES',3}}}}),
   E('apples',nil,true),E('Apples',nil,true),E('APPLES',nil,true),
   cmd('store_pair',{key='other',value=4}),cmd('clear'),cmd('cache_keys')},options)
  add(label..'_intermediates',{
   cmd('store',{values=H{a=1,b=H{c=2}}}),E('b',nil,true),E('b.c',nil,true),
   cmd('store_pair',{key='b.c',value=9}),E('b.c',nil,true),
   cmd('store_pair',{key='b',value=4}),E('b.c',nil,true),
   cmd('store',{values=H{b=H{d=3}}}),E('b.c',nil,true),E('b.d',nil,true)},options)
  add(label..'_nested_pair',{
   cmd('store_pair',{key='b',value=H{c=2}}),E('b',nil,true),E('b.c',nil,true),
   E('b.c',H{b=H{c=5}},true),cmd('memory')},options)
  add(label..'_restore',{
   cmd('store',{values=H{a=false,b=2}}),E('a',H{a=7},true),E('a',nil,true),
   E('missing+b',H{b=10},true),E('b',nil,true),E('b',H{b={null=true}},true),cmd('memory')},options)
 end
end
add('nested_hashes',{cmd('store',{values=H{a=H{basket=H{of='apples'}},b=2}}),
 E('a.basket.of',nil,true),E('a.basket',nil,true),E('b',nil,true),
 E('`a.basket.of`',nil,true),E('`a.basket`',nil,true)})
add('arrays',{cmd('store',{values=H{a={1,2,3}}}),E('a[0]',nil,true),E('a[x]',H{x=1},true),E('a[x+1]',H{x=1},true),E('a[1][0]',H{a={{1},{2,3}}},true)})
add('nil_and_pair_overload',{cmd('store',{values=H{a={null=true}}}),E('a',nil,true),cmd('store_pair',{key='a',value={null=true}}),cmd('memory')})
for _,cache in ipairs{false,true} do
 local options={cache_ast=cache}
 local label=cache and 'cached' or 'uncached'
 add(label..'_ast',{
  cmd('ast',{expression='1+1'}),cmd('ast',{expression='1 + 1'}),cmd('ast',{expression='a+1'}),
  cmd('ast',{expression='1+'}),E('missing+1',nil,true),E('missing+1'),
  cmd('cache_keys'),cmd('clear'),cmd('cache_keys')},options)
 add(label..'_disable',{
  cmd('ast',{expression='1+1'}),cmd('disable_cache_status'),
  cmd('disable_cache_eval',{expression='2+2'}),cmd('cache_enabled'),
  cmd('disable_cache_eval',{expression='missing'}),cmd('cache_enabled'),E('3+3',nil,true)},options)
 add(label..'_warm',{
  cmd('warm_cache',{entries={hash={{'answer','40+2'},{'1+1','9'}}}}),
  E('answer',nil,true),E('1+1',nil,true),cmd('disable_cache_eval',{expression='answer'}),
  cmd('clear_cache',{key='1+1'}),E('1+1',nil,true),
  cmd('clear_cache',{key='missing'}),cmd('clear_cache'),cmd('cache_keys')},options)
 add(label..'_bulk_strict',{
  E({'1+1','missing','2+2'},nil,true),cmd('cache_keys'),
  E({hash={{S('first'),'1+1'},{'missing','other'},{S('last'),'2+2'}}},nil,true),cmd('cache_keys')},options)
 add(label..'_bulk_permissive',{
  E({'1+1','missing','2+2'}),E({hash={{S('first'),'1+1'},{'missing','other'},{S('last'),'2+2'}}}),
  E({1,2,3},nil,true),E({'1+1',{'3+3','missing'}})},options)
 add(label..'_range',{
  E('"a"[9223372036854775808]'),E({'1+1','"a"[9223372036854775808]','2+2'}),
  E('1 / 0'),E('1 / 0',nil,true)},options)
end
for _,name in ipairs{'Äpfel','İTEM','Straße','Σigma'} do
 for _,sensitive in ipairs{false,true} do
  add('unicode_'..#cases,{
   cmd('store_pair',{key=name,value=12}),E('`'..name..'`',nil,true),
   cmd('store_pair',{key=name,value=13}),cmd('memory')},{case_sensitive=sensitive,cache_ast=true})
 end
end
for _,key in ipairs{true,false,12,{integer='123456789012345678901234567890'},{symbol='Hello'},{decimal='1.20'}} do
 add('pair_key_'..#cases,{cmd('store_pair',{key=key,value=3}),cmd('memory')})
end
add('explicit_mode',{
 E('MAP(items, x, x+missing)',H{items={1,2},__evaluation_mode=S('strict')}),
 E('MAP(items, x, x+missing)',H{items={1,2},__evaluation_mode=S('permissive')},true),cmd('memory')},{cache_ast=true})
add('open_index_eof',{
 E('"abc"[1',nil,true),E('{10,20}[1',nil,true),E('2+{10,20}[1',nil,true),
 E('a[0][1',H{a={{1,2}}},true),E('"a"[9223372036854775808',nil,true)
},{cache_ast=true})
local function literal(value)
 if type(value)=='string' then return string.format('%q',value) end
 if type(value)=='number' or type(value)=='boolean' then return tostring(value) end
 local parts={}
 if #value>0 then for i,v in ipairs(value) do parts[i]=literal(v) end
 else local keys={};for k in pairs(value) do keys[#keys+1]=k end;table.sort(keys);for i,k in ipairs(keys) do parts[i]='['..literal(k)..']='..literal(value[k]) end end
 return '{'..table.concat(parts,',')..'}'
end
local f=assert(io.open(assert(arg[1],'output required'),'w'));f:write('return {\n');for _,case in ipairs(cases) do f:write(literal(case),',\n') end;f:write('}\n');f:close()
print(#cases..' persistent calculator sessions')
