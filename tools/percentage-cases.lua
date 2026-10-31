local cases={}
local function add(id,formula,context,operation)
 if operation=="value" then operation=nil end
 cases[#cases+1]={id='percentage_'..id,formula=formula,context=context or {},operation=operation,expected='pending'}
end
local formulas={'5%','400/60%','ROUND(400/60%,2)','ROUND((400/60%)*1,2)','ROUND(60% * 1,2)','50% + 50%',
 '50.0%','-5%','(-5)%','5%%','50%2','50%(-2)','50%+2','50%-2','50%*2','50%/2','50% %2',
 '2*50%','(2*50)%','2+50%','(2+50)%','SUM((5%),1)','SUM(5%,1)','SUM(5%)','{5%}',
 '5%<1','(5%)<1','5% = 0.05','IF(TRUE,5%,2)','IF(TRUE,(5%),2)','{50%+2}','50%[0]',
 '%5','5%+','5% 2','5 % -2','5 % +2','5%AND TRUE','(5%) AND TRUE','5% %','NULL%','TRUE%','"5"%',
 'IF(FALSE,"a"%,1)','{1,2}%'}
for i,s in ipairs(formulas) do for _,op in ipairs{'value','class','type','identifiers'} do add(('syntax_%d_%s'):format(i,op),s,{},op=='value' and nil or op) end end
local values={5,{integer='9007199254740993'},{integer='1'..string.rep('0',400)},{decimal='0.1'},{decimal='-0'},
 {decimal='Infinity'},{decimal='NaN'},{float_words={0,0}},{float_words={0x80000000,0}},
 {float_words={0x3ff00000,1}},{float_words={0x7fefffff,0xffffffff}},{float_words={0,1}},
 {float_words={0x7ff00000,0}},{float_words={0xfff00000,0}},{float_words={0x7ff80000,1}},
 '2.5','bad',false,{null=true},{1,2}}
for i,v in ipairs(values) do
 for j,s in ipairs{'x%','IF(FALSE,x%,7)','(x%)+1','x%%'} do
  add(('value_%d_%d'):format(i,j),s,{x=v})
  add(('class_%d_%d'):format(i,j),s,{x=v},'class')
 end
 add('dependency_'..i,'x%',{x=v},'dependencies')
end
for i,s in ipairs{"15 % 8","15 % (4 * 2)"} do
 for _,op in ipairs{"value","class","type","identifiers"} do add(("upstream_modulo_%d_%s"):format(i,op),s,{},op) end
end
local function literal(v)
 if type(v)=='string' then return string.format('%q',v) end
 if type(v)=='number' or type(v)=='boolean' then return tostring(v) end
 local p={};if #v>0 then for i,x in ipairs(v) do p[i]=literal(x) end else local k={};for x in pairs(v) do k[#k+1]=x end;table.sort(k);for i,x in ipairs(k) do p[i]='['..literal(x)..']='..literal(v[x]) end end;return '{'..table.concat(p,',')..'}'
end
local f=assert(io.open(assert(arg[1],'output path required'),'w'));f:write('return {\n');for _,c in ipairs(cases) do f:write(literal(c),',\n') end;f:write('}\n');f:close()
print(#cases..' percentage syntax and numeric dispatch probes generated')
