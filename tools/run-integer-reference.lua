-- Separate reference profile for fixture Integer strings, not formula coverage.
local storage=assert(arg[1], 'usage: lua tools/run-integer-reference.lua STORAGE RUNROOT OUTPUT')
local runroot=assert(arg[2]);local output=assert(arg[3])
local probe=[=[
raise "unexpected Ruby #{RUBY_VERSION}" unless RUBY_VERSION == '3.3.13'
alphabet=%w[0 1 2 7 8 9 a b d o x _ + -]
inputs=['']
(1..3).each { |n| alphabet.repeated_permutation(n) { |chars| inputs << chars.join } }
%w[0b 0B 0o 0O 0d 0D 0x 0X].each do |prefix|
  ['', '+', '-'].each do |sign|
    %w[0 1 7 8 9 a f 10 010 101 1_0 _1 1_ 1__0].each do |digits|
      raw=sign+prefix+digits
      inputs << raw
      [" ","\t","\n","\r","\v","\f"].each { |space| inputs << space+raw+space }
    end
  end
end
inputs += ["+ 1","- 1","0x 1","1 + 2","1e2","0.0","00.1","0_9","0b2","0o8","0xG","0dA","0x_1","0_b1","1\0","\0","１２","١٢","−1"," 1"]
%w[0b 0o 0d 0x].zip(%w[1 7 9 f]).each do |prefix,digit|
  ['', '+', '-'].each do |sign|
    inputs << sign+prefix+digit*128
    inputs << "\t"+sign+prefix+([digit]*128).join('_')+"\r\n"
  end
end
inputs += ['9'*400, '-'+('9'*400), '0000000', '+0', '-0', '0_0']
puts '# Ruby 3.3.13 Integer(String), inferred base; hex-encoded input bytes'
inputs.uniq.sort.each do |text|
  value=begin Integer(text).to_s; rescue ArgumentError; 'reject'; end
  puts "#{text.unpack1('H*')}\t#{value}"
end
]=]
local function quote(s)return "'"..s:gsub("'","'\\''").."'" end
local args={'podman','--root',storage,'--runroot',runroot,'run','--rm','--cgroups=disabled','--network=host','--security-opt','label=disable',os.getenv('FORMULA_REFERENCE_IMAGE') or 'localhost/formula-dentaku-reference:3.3.13','ruby','-e',probe}
local escaped={};for i,s in ipairs(args)do escaped[i]=quote(s)end
local pipe=assert(io.popen(table.concat(escaped,' ')));local result=pipe:read('a');local ok,_,code=pipe:close();assert(ok,'reference exit '..tostring(code))
local f=assert(io.open(output,'w'));f:write(result);assert(f:close())
