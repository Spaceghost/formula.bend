-- Explicit raw words preserve Float inputs across Lua, JSON and every backend.
local cases = {}
local function add(id, formula, context, operation)
  cases[#cases+1] = {id='float_value_'..id,formula=formula,context=context,operation=operation,expected='pending'}
end
local words = {
  {0,0},{0x80000000,0},{0x3ff00000,1},{0x3fb99999,0x9999999a},
  {0x3fb1eb85,0x1eb851ec},{0x400c0000,0},{0xc00c0000,0},
  {0,1},{0x43400000,0},{0x7fefffff,0xffffffff},
  {0x7ff00000,0},{0xfff00000,0},{0x7ff80000,1},
}
local formulas = {'x','-x','ABS(x)','x+1','1+x','x-1','x*2','2*x',
 'x+0.1','0.1+x','x*0.1','x/3','3/x','x%3','3%x',
 'x=1','x<>1','x<1','x<=1','x>1','x>=1','x=1.0','1.0=x',
 'IF(x,7,missing)','NOT(x)','SUM(x,1)','MUL(x,2)','AVG(x,2)',
 'MIN(x,2)','MAX(x,2)','COUNT(x)','{x}[0]','LEN(CONCAT(x))'}
for i,value in ipairs(words) do
 local context={x={float_words=value}}
 for j,formula in ipairs(formulas) do add(i..'_'..j,formula,context) end
 for _,operation in ipairs{'class','coerce','coerce_class'} do
  add(i..'_'..operation, 'x', operation:find('coerce',1,true) and {input={float_words=value}} or context, operation)
 end
end
for i,value in ipairs(words) do
 for _,places in ipairs{-2,-1,0,1,2,15} do
  for _,name in ipairs{'ROUND','ROUNDUP','ROUNDDOWN'} do
   add(('round_%d_%d_%s'):format(i,places,name),('%s(x,%d)'):format(name,places),{x={float_words=value}})
  end
 end
end
local hard_words={
 {0x40056666,0x66666666},{0x3ff0147a,0xe147ae14},
 {0x3fa70a3d,0x70a3d70a},{0xbfa70a3d,0x70a3d70a},
 {0x3ff3c0ca,0x428c59fb},{0x000730d6,0x7819e8d2},{0x800730d6,0x7819e8d2},
 {0x000fffff,0xffffffff},{0x00100000,0},words[8],{0x80000000,1},
}
for i,value in ipairs(hard_words) do
 for _,places in ipairs{0,1,2,14,15,16,17,22,300,308,323,324,350,374,375,1074} do
  for _,name in ipairs{'ROUND','ROUNDUP','ROUNDDOWN'} do
   add(('hard_round_%d_%d_%s'):format(i,places,name),('%s(x,%d)'):format(name,places),{x={float_words=value}})
  end
 end
end
for i,formula in ipairs{'x+MIN(n,2)','MIN(n,2)+x','x*MIN(n,2)','SUM(MIN(n,2),x)',
 'CONCAT(MIN(n,2))','IF(FALSE,MIN(n,2),x)','IF(TRUE,MIN(n,2),x)',
 'MIN(2,n)','MAX(2,n)','ROUNDUP("bad",n)','ROUND("bad",n)',
 'SUM(x,x,-x)','MUL(x,2)','SUM(x,x)','MIN(n,2,"bad")'} do
 add('error_and_order_'..i,formula,{x={float_words=words[10]},n={float_words=words[13]}})
end
for _,method in ipairs{'ROUND','ROUNDUP','ROUNDDOWN'} do
 for i,precision in ipairs{{float_words=words[6]},{float_words=words[11]},{null=true},false,
  {integer='2147483648'},{integer='-2147483649'},{integer='99999999999999999999999999999999999'}} do
  add(('precision_%s_%d'):format(method,i),method..'(x,p)',{x={float_words=words[3]},p=precision})
 end
end
for _,integer in ipairs{'9007199254740991','9007199254740992','9007199254740993','9007199254740994',
 '1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'} do
 for j,formula in ipairs{'x=y','x<y','x>y','x+y','y+x','x*y'} do
  add('integer_'..integer..'_'..j,formula,{x={float_words=words[9]},y={integer=integer}})
 end
end
for _,decimal in ipairs{'0','-0','1','1.0000000000000002','Infinity','-Infinity','NaN'} do
 for i,value in ipairs{words[1],words[3],words[4],words[11],words[12],words[13]} do
  for j,formula in ipairs{'x+y','y+x','x*y','y*x','x=y','y=x','x<y'} do
   add(('decimal_%s_%d_%d'):format(decimal,i,j),formula,{x={float_words=value},y={decimal=decimal}})
  end
 end
end
for i,formula in ipairs{'{1,2}*x','{x}-{y}','{y}-{x}','CONTAINS(x,{y})','IF(TRUE,x,missing)'} do
 add('array_'..i,formula,{x={float_words=words[3]},y={decimal='1'}})
end
local upstream={
 {'upstream_roundup_exact_07','ROUNDUP(x,1)',{float_words={1072064102,1717986918}}},
 {'upstream_roundup_exact_007','ROUNDUP(x,2)',{float_words=words[5]}},
 {'upstream_rounddown_exact_029','ROUNDDOWN(x,2)',{float_words={1070763868,687194767}}},
 {'upstream_rounddown_exact_115','ROUNDDOWN(x,2)',{float_words={1072850534,1717986918}}},
 {'upstream_roundup_float_type','ROUNDUP(x,3)',{float_words={1072938719,2755651017}}},
 {'upstream_roundup_integer_type','ROUNDUP(x,-1)',{float_words={1083394560,0}}},
 {'upstream_roundup_decimal_type','ROUNDUP(1.2341,3)',0},
 {'upstream_rounddown_float_type','ROUNDDOWN(x,3)',{float_words={1072939558,2157791570}}},
 {'upstream_rounddown_integer_type','ROUNDDOWN(x,-1)',{float_words={1083394560,0}}},
 {'upstream_rounddown_decimal_type','ROUNDDOWN(1.2349,3)',0},
}
for _,case in ipairs(upstream) do
 add(case[1],case[2],{x=case[3]})
 add(case[1]..'_class',case[2],{x=case[3]},'class')
end
local function literal(value)
 if type(value)=='string' then return string.format('%q',value) end
 if type(value)=='number' or type(value)=='boolean' then return tostring(value) end
 local parts={}
 if #value>0 then for i,item in ipairs(value) do parts[i]=literal(item) end
 else
  local keys={};for key in pairs(value) do keys[#keys+1]=key end;table.sort(keys)
  for i,key in ipairs(keys) do parts[i]='['..literal(key)..']='..literal(value[key]) end
 end
 return '{'..table.concat(parts,',')..'}'
end
if arg[2] then
 local expected={}
 for line in io.lines(arg[2]) do local id,value=line:match('^([^\t]+)\t(.*)$');assert(id,'invalid oracle row');assert(not expected[id],'duplicate oracle id');expected[id]=value end
 for _,case in ipairs(cases) do case.expected=assert(expected[case.id],'missing oracle id: '..case.id);expected[case.id]=nil end
 assert(next(expected)==nil,'unexpected oracle ids')
end
local f=assert(io.open(assert(arg[1],'output path required'),'w'))
f:write('return {\n');for _,case in ipairs(cases) do f:write(literal(case),',\n') end;f:write('}\n');f:close()
print(#cases..' Float binding, arithmetic, coercion, comparison and rounding cases')
