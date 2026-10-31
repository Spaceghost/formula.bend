-- Produce independent TokenMatcher probes; expected values come only from Ruby.
local cases={}
local null={null=true}
local function S(s) return {symbol=s} end
local function H(t)
 local keys={};for k in pairs(t) do keys[#keys+1]=k end;table.sort(keys)
 local pairs={};for _,k in ipairs(keys) do pairs[#pairs+1]={S(k),t[k]} end
 return {hash=pairs}
end
local function T(c,v,r) return H{category=c or null,value=v==nil and null or v,raw_value=r==nil and null or r} end
local function add(id,op,input) cases[#cases+1]={id='matcher_'..id,operation='token_matcher',formula=op,context={input=H(input)},expected='pending'} end
local builtins={'datetime','numeric','string','logical','value','addsub','subtract','anchored_minus','muldiv','pow','mod','combinator','comparator','comp_gt','comp_lt','open','close','comma','non_group','non_group_star','non_close_plus','arguments','if','round','roundup','rounddown','not'}
local tokens={null,T(S('datetime'),'2026-10-31'),T(S('numeric'),5,'5'),T(S('string'),'rhubarb'),T(S('logical'),false),
 T(S('operator'),S('add')),T(S('operator'),S('subtract')),T(S('operator'),S('multiply')),T(S('operator'),S('divide')),T(S('operator'),S('pow')),T(S('operator'),S('mod')),
 T(S('combinator'),S('and')),T(S('comparator'),S('gt')),T(S('comparator'),S('ge')),T(S('comparator'),S('lt')),T(S('comparator'),S('le')),
 T(S('grouping'),S('open')),T(S('grouping'),S('close')),T(S('grouping'),S('comma')),
 T(S('function'),S('if')),T(S('function'),S('round')),T(S('function'),S('roundup')),T(S('function'),S('rounddown')),T(S('function'),S('not')),T(S('identifier'),S('hello')),T('numeric',5),T(null,null)}
for _,name in ipairs(builtins) do
 local matcher=H{builtin=name}
 add('builtin_'..name..'_describe','describe',{matcher=matcher})
 for i,token in ipairs(tokens) do add('builtin_'..name..'_token_'..i,'accept',{matcher=matcher,token=token}) end
end
local descriptors={
 H{},H{categories=S('numeric')},H{categories={S('numeric'),S('string')}},
 H{categories=S('operator'),values={S('add'),S('subtract')}},
 H{categories={{S('numeric'),null},{S('string'),S('numeric')}}},
 H{categories={null}},H{values={1,{decimal='1'},'1',S('one')}},
 H{values={{decimal='-0'}}},H{values={0}},H{values={false}},
 H{children={H{builtin='numeric'},null,H{builtin='string'}}},
 H{builtin='numeric',alternatives={H{builtin='string'}}},
 H{builtin='numeric',alternatives={H{builtin='string'},H{builtin='logical'}}}
}
local mods={{},{'invert'},{'invert','invert'},{'caret'},{'star'},{'plus'},{'star','plus'},{'plus','star'},{'invert','star'},{'caret','plus'}}
local extra_tokens={T(S('numeric'),{decimal='1'}),T(S('numeric'),1),T(S('numeric'),{decimal='0'}),T(S('numeric'),{decimal='-0'}),T(S('numeric'),0),T(S('numeric'),false)}
for i,matcher in ipairs(descriptors) do
 for j,modifiers in ipairs(mods) do
  local fields={};for _,pair in ipairs(matcher.hash) do fields[pair[1].symbol]=pair[2] end
  fields.modifiers=modifiers
  local changed=H(fields)
  add('custom_'..i..'_mod_'..j..'_describe','describe',{matcher=changed})
  for k,token in ipairs(extra_tokens) do add('custom_'..i..'_mod_'..j..'_token_'..k,'accept',{matcher=changed,token=token}) end
  add('custom_'..i..'_mod_'..j..'_nil','accept',{matcher=changed,token=null})
 end
end
local sequences={
 {T(S('numeric'),5),T(S('numeric'),11),T(S('numeric'),9),T(S('numeric'),24),T(S('identifier'),S('hello')),T(S('numeric'),8)},
 {T(S('numeric'),1),T(S('grouping'),S('comma')),T(S('numeric'),2),T(S('grouping'),S('comma')),T(S('logical'),true),T(S('grouping'),S('comma')),T(S('string'),'olive'),T(S('grouping'),S('comma')),T(S('grouping'),S('open'))},
 {},{T(S('numeric'),1),null,T(S('numeric'),2)},
 {T(S('numeric'),1),T(S('numeric'),2),T(S('numeric'),3)}
}
for i,stream in ipairs(sequences) do
 for j,modifiers in ipairs({{}, {'star'}, {'plus'}, {'star','plus'}, {'caret','plus'}}) do
  for offset=-11,11 do
   add('stream_'..i..'_mod_'..j..'_offset_'..offset,'match',{matcher=H{builtin='numeric',modifiers=modifiers},stream=stream,offset=offset})
  end
 end
 add('arguments_stream_'..i,'match',{matcher=H{builtin='arguments'},stream=stream})
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
print(#cases..' TokenMatcher probes')
