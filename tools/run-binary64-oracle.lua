-- Ruby Float is the native binary64 reference for this foundational layer.
-- These are not Dentaku formula cases or evidence of evaluator Float support.
local project = assert(arg[1], 'usage: lua tools/run-binary64-oracle.lua PROJECT GEMS STORAGE RUNROOT INPUT OUTPUT')
local gems = assert(arg[2], 'missing gems directory')
local storage = assert(arg[3], 'missing container storage')
local runroot = assert(arg[4], 'missing container runroot')
local input = assert(arg[5], 'missing relative input')
local output = assert(arg[6], 'missing output')
assert(not input:match('^/') and not input:match('%.%.'), 'input must be project-relative')
local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local probe = [[
File.foreach(ENV.fetch('BINARY64_INPUT')) do |line|
  id, op, ah, al, bh, bl = line.split
  a = [Integer(ah), Integer(al)].pack('NN').unpack1('G')
  b = [Integer(bh), Integer(bl)].pack('NN').unpack1('G')
  if op == 'words'
    puts "#{id}\t#{[a].pack('G').unpack('NN').join(':')}"
    next
  end
  if op == 'compare'
    order = a <=> b
    puts "#{id}\t#{order.nil? ? 'unordered' : {-1=>'lt', 0=>'eq', 1=>'gt'}.fetch(order)}"
    next
  end
  value = case op
  when 'add' then a + b
  when 'subtract' then a - b
  when 'multiply' then a * b
  when 'divide' then a / b
  when 'roundtrip' then a
  else raise 'unknown operation'
  end
  snapshot = value.nan? ? 'nan' : [value].pack('G').unpack('NN').join(':')
  puts "#{id}\t#{snapshot}"
end
]]
local args = {'podman','--root',storage,'--runroot',runroot,'run','--rm',
  '--cgroups=disabled','--network=host','--security-opt','label=disable',
  '-e','GEM_HOME=/gems','-e','GEM_PATH=/gems',
  '-e','BINARY64_INPUT=/formula/'..input,
  '-v',gems..':/gems','-v',project..':/formula:ro',
  os.getenv('FORMULA_REFERENCE_IMAGE') or 'localhost/formula-dentaku-reference:3.3.13',
  'ruby','-e',probe}
local escaped = {}; for i,arg in ipairs(args) do escaped[i] = quote(arg) end
local pipe = assert(io.popen(table.concat(escaped,' '), 'r'))
local result = assert(pipe:read('*a'))
local ok, _, code = pipe:close()
assert(ok, 'binary64 oracle failed, output not replaced: '..tostring(code))
local f = assert(io.open(output, 'w')); assert(f:write(result)); assert(f:close())
