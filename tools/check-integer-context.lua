local directory=debug.getinfo(1,'S').source:match('^@(.*/)') or './'
local IntegerContext=dofile(directory..'integer-context.lua')
local path=arg[1] or 'compat/integer-context-oracle.tsv'
local total,accepted,rejected=0,0,0
for line in io.lines(path)do
 if line:sub(1,1)~='#' then
  local hex,expected=line:match('^([0-9a-f]*)\t(.+)$')
  assert(hex and expected, 'invalid profile row')
  assert(#hex%2==0,'odd input byte encoding')
  local text=hex:gsub('..',function(pair)return string.char(tonumber(pair,16))end)
  local ok,actual=pcall(IntegerContext.canonical,text)
  if not ok then actual='reject' end
  assert(actual==expected,('Integer(%q): expected %s, got %s'):format(text,expected,tostring(actual)))
  total=total+1
  if expected=='reject' then rejected=rejected+1 else accepted=accepted+1 end
 end
end
assert(total>0,'empty integer context profile')
print(('%d Integer string checks passed (%d accepted, %d rejected)'):format(total,accepted,rejected))
