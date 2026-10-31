local cases={}
local function S(s) return {symbol=s} end
local null={null=true}
local function H(t)
 local names={};for k in pairs(t) do names[#names+1]=k end;table.sort(names)
 local pairs={};for _,k in ipairs(names) do pairs[#pairs+1]={S(k),t[k]} end
 return {hash=pairs}
end
local function C(op,t) t=t or {};t.op=op;return H(t) end
local function E(expression,data,strict) return C(strict and 'evaluate!' or 'evaluate',{expression=expression,data=data or H{}}) end
local function add(id,options,commands)
 cases[#cases+1]={id='calculator_origin_'..id,operation='calculator_session',formula='',context={input=H{options=H(options),commands=commands}},expected='pending'}
end
local bodies={'A','a','A+a','IF(TRUE,A,a)','MAP(items, X, X+A)','REDUCE(items,m,X,m+X+A,0)','Äpfel','İTEM'}
for _,origin in ipairs{false,true} do
 for _,receiver in ipairs{false,true} do
  for i,body in ipairs(bodies) do
   local label=(origin and 'sensitive' or 'folded')..'_to_'..(receiver and 'sensitive' or 'folded')..'_'..i
   add(label,{case_sensitive=receiver,cache_ast=true},{
    C('store',{values={hash={{S('A'),10},{S('a'),20},{S('items'),{1,2}},{S('Äpfel'),30},{S('äpfel'),40},{S('İTEM'),50},{S('i̇tem'),60}}}}),
    C('warm_cache_from',{source_sensitive=origin,entries={hash={{'probe',body}}}}),
    E('probe',nil,true),E('probe'),C('disable_cache_eval',{expression='probe'}),
    E('probe',H{A=70,a=80,items={3}},true),
    C('cache_keys'),C('memory')
   })
  end
 end
end
local values={
 H{},H{a=1},H{a=null},H{A=1,a=2,b=H{c=3}},
 {},{{'a',1},{'b',2}},{{'A',1},{'a',2},{'b',null}},
 {{'a'},{},{'b',3,4},'scalar',false,12},
 'bad',false,12,null,
}
for _,nested in ipairs{false,true} do
 for _,sensitive in ipairs{false,true} do
  for i,value in ipairs(values) do
   for _,overload in ipairs{'store','store_pair'} do
    local command=overload=='store' and C('store',{values=value}) or C('store_pair',{key=value,value=null})
    add('storage_'..(nested and 'nested' or 'flat')..'_'..(sensitive and 'sensitive' or 'folded')..'_'..i..'_'..overload,
     {nested_data_support=nested,case_sensitive=sensitive},{
      C('store',{values=H{saved=99}}),command,C('memory'),E('saved',nil,true),E('a',nil,true)
     })
   end
  end
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
print(#cases..' cache-origin and storage-overload sessions')
