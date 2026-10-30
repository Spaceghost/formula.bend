-- Reference-only probe: no Ruby code is used by the Bend application.
local project = assert(arg[1], 'usage: lua tools/run-oracle.lua PROJECT UPSTREAM GEMS STORAGE RUNROOT OUTPUT')
local upstream = assert(arg[2], 'missing upstream directory')
local gems = assert(arg[3], 'missing gems directory')
local storage = assert(arg[4], 'missing container storage directory')
local runroot = assert(arg[5], 'missing container runroot')
local output = assert(arg[6], 'missing output file')
local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function command(args)
  local escaped = {}
  for i, value in ipairs(args) do escaped[i] = quote(value) end
  return table.concat(escaped, ' ')
end
local probe = [[
File.foreach('/formula/build/scalar-corpus.formulas.tsv') do |line|
  id, source, operation = line.chomp.split("\t", 3)
  begin
    calculator = Dentaku::Calculator.new
    value = case operation
    when 'identifiers' then calculator.identifiers(source)
    when 'dependencies' then calculator.dependencies(source)
    else calculator.evaluate!(source)
    end
    snapshot = case value
    when nil then 'null'
    when true, false then "boolean:#{value}"
    when BigDecimal then "number:#{value.to_s('F').sub(/\.0+\z/, '')}"
    when Integer then "number:#{value}"
    when String then "string:#{value}"
    when Array then "names:#{value.join(',')}"
    else raise "unhandled oracle type #{value.class}"
    end
  rescue Dentaku::Error => error
    snapshot = "error:#{error.class.name}"
  end
  puts "#{id}\t#{snapshot}"
end
]]
local args = {
  'podman','--root',storage,'--runroot',runroot,'run','--rm',
  '--cgroups=disabled','--network=host','--security-opt','label=disable',
  '-e','GEM_HOME=/gems','-e','GEM_PATH=/gems',
  '-v',gems .. ':/gems','-v',upstream .. ':/reference:ro',
  '-v',project .. ':/formula:ro','-w','/reference',
  os.getenv('FORMULA_REFERENCE_IMAGE') or 'localhost/formula-dentaku-reference:3.3.13',
  'ruby','-Ilib','-rdentaku','-e',probe,
}
local pipe = assert(io.popen(command(args), 'r'))
local result = assert(pipe:read('*a'))
local ok, _, code = pipe:close()
assert(ok, 'oracle failed; output was not replaced (exit ' .. tostring(code) .. ')')
local file = assert(io.open(output, 'w'))
file:write(result); file:close()
