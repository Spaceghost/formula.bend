local values={"1 @ 2","1.2.3","1 2",".",".3","1..2","..","a..b","a.2","1.@","1.2.3@","'missing","1.2.3.4","1.2.",".a",".a.","a.","1.a",".2a","..2","1...2"}
local f=assert(io.open(assert(arg[1],'output path required'),'w'));f:write('return {\n')
for i,source in ipairs(values) do f:write(('{id=%q,formula=%q,expected="pending"},\n'):format('lexical_dot_boundary_'..i,source)) end
f:write('}\n');f:close()
print(#values..' lexical boundary probes')
