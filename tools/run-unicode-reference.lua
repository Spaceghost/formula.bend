-- Reference-only Unicode profile from Ruby's own regular expressions.
local storage=assert(arg[1], 'usage: lua tools/run-unicode-reference.lua STORAGE RUNROOT OUTPUT')
local runroot=assert(arg[2], 'missing runroot')
local output=assert(arg[3], 'missing output')
local function q(s) return "'"..s:gsub("'","'\\''").."'" end
local probe=[=[
require 'rbconfig'
puts "# Ruby #{RUBY_VERSION}; Unicode #{RbConfig::CONFIG['UNICODE_VERSION']}"
[ ['alpha', /[[:alpha:]]/], ['word', /[[:word:]]/] ].each do |name, pattern|
  first = last = nil
  (128..0x10ffff).each do |cp|
    next if (0xd800..0xdfff).include?(cp)
    c = cp.chr(Encoding::UTF_8)
    if pattern.match?(c)
      first ||= cp
      last = cp
    elsif first
      puts "#{name}\t#{first}\t#{last}"
      first = last = nil
    end
  end
  puts "#{name}\t#{first}\t#{last}" if first
end
(128..0x10ffff).each do |cp|
  next if (0xd800..0xdfff).include?(cp)
  c = cp.chr(Encoding::UTF_8)
  ['lower','fold'].each do |kind|
    mapped = kind == 'lower' ? c.downcase : c.downcase(:fold)
    puts "#{kind}\t#{cp}\t#{mapped.codepoints.join(',')}" unless mapped == c
  end
end
]=]
local args={'podman','--root',storage,'--runroot',runroot,'run','--rm','--cgroups=disabled','--network=host','--security-opt','label=disable','localhost/formula-dentaku-reference:3.3.13','ruby','-e',probe}
for i,s in ipairs(args) do args[i]=q(s) end
local pipe=assert(io.popen(table.concat(args,' '))); local result=pipe:read('*a'); assert(pipe:close()); local f=assert(io.open(output,'w')); f:write(result); f:close()
