local cases={}
local function S(s) return {symbol=s} end
local function H(t)
 local names={};for k in pairs(t) do names[#names+1]=k end;table.sort(names)
 local items={};for _,k in ipairs(names) do items[#items+1]={S(k),t[k]} end
 return {hash=items}
end
local function P(source,sensitive) return H{source=source,sensitive=not not sensitive} end
local function add(id,source,data,programs,receiver,root)
 data=data or {};data.__evaluation_mode=S('strict')
 cases[#cases+1]={id='stored_value_'..id,operation='stored_value',formula='',context={input=H{source=source,data=H(data),programs=H(programs or {}),receiver_sensitive=not not receiver,root_sensitive=root==nil and not not receiver or root}},expected='pending'}
end
local examples={
 {'simple','f+1',{a=2},{f=P('a*3')}},
 {'transitive','g+f',{a=2},{f=P('a*3'),g=P('f+2')}},
 {'twice','f+f',{a=4},{f=P('a+1')}},
 {'array','{f,g}',{a=4},{f=P('a+1'),g=P('f*2')}},
 {'stored_array','f[1]',{}, {f=P('{10,20,30}')}},
 {'stored_text','LEN(f)',{}, {f=P('"hello"')}},
 {'stored_false','IF(f,10,20)',{}, {f=P('FALSE')}},
 {'stored_null','f[missing]',{}, {f=P('NULL')}},
 {'missing','f+1',{}, {f=P('absent+2')}},
 {'divide_zero','f+1',{}, {f=P('1/0')}},
 {'unused_if','IF(FALSE,f,42)',{}, {f=P('absent+2')}},
 {'unused_and','FALSE AND f',{}, {f=P('absent+2')}},
 {'unused_or','TRUE OR f',{}, {f=P('absent+2')}},
 {'map','MAP(items,x,f)',{items={1,2,3}},{f=P('x*2')}},
 {'map_shadow','MAP(items,f,f+1)',{items={1,2,3}},{f=P('absent')}},
 {'nested_map','MAP(items,x,SUM(MAP(items,y,f)))',{items={1,2}},{f=P('x+y')}},
 {'filter','FILTER(items,x,f)',{items={1,2,3}},{f=P('x>1')}},
 {'all','ALL(items,x,f)',{items={1,2,3}},{f=P('x>0')}},
 {'any','ANY(items,x,f)',{items={1,2,3}},{f=P('x>2')}},
 {'reduce','REDUCE(items,m,x,f,0)',{items={1,2,3}},{f=P('m+x')}},
 {'case','CASE f WHEN 2 THEN g ELSE 0 END',{a=1},{f=P('a+1'),g=P('f*3')}},
 {'nested_hash','f+1',{user=H{score=4}},{f=P('user.score')}},
 {'big_integer','f+1',{a={integer='9007199254740993'}},{f=P('a*2')}},
 {'decimal','f+0.1',{a={decimal='1.25'}},{f=P('a*2')}},
 {'root_parse_error','f+',{}, {f=P('1')}},
 {'root_token_error','@',{}, {f=P('1')}},
}
for _,e in ipairs(examples) do add(e[1],e[2],e[3],e[4]) end
for _,receiver in ipairs{false,true} do
 for _,origin in ipairs{false,true} do
  for _,root in ipairs{false,true} do
   for _,expression in ipairs{'F','f','F+f','MAP(items,X,F)','MAP(items,x,F)','IF(TRUE,F,f)'} do
    add('mode_'..tostring(receiver)..'_'..tostring(origin)..'_'..tostring(root)..'_'..#cases,expression,
     {A=10,a=20,items={1,2},X=30,x=40},{F=P('A+X',origin)},receiver,root)
   end
  end
 end
end
for _,depth in ipairs{1,2,16,64,257} do
 local programs={};for i=1,depth do programs['f'..i]=P((i==1 and 'base' or 'f'..(i-1))..'+1') end
 add('chain_'..depth,'f'..depth,{base=0},programs)
end
for _,depth in ipairs{0,1,5,25,65} do
 add('recursive_local_'..depth,'MAP({'..depth..'},n,f)',{n=0},
  {f=P('IF(n>0,1+SUM(MAP({n-1},n,f)),0)')})
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
print(#cases..' stored AST value probes')
