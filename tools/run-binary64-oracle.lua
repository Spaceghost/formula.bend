-- Ruby Float is the native binary64 reference for this foundational layer.
-- These are not Dentaku formula cases or evidence of evaluator Float support.
-- Decimal conversion uses exact rational rounding intervals. Ruby's bundled
-- decimal parsing differences are recorded separately, never silently adopted
-- as IEEE expectations or hidden as passing Ruby compatibility cases.
local project = assert(arg[1], 'usage: lua tools/run-binary64-oracle.lua PROJECT GEMS STORAGE RUNROOT INPUT OUTPUT')
local gems = assert(arg[2], 'missing gems directory')
local storage = assert(arg[3], 'missing container storage')
local runroot = assert(arg[4], 'missing container runroot')
local input = assert(arg[5], 'missing relative input')
local output = assert(arg[6], 'missing output')
assert(not input:match('^/') and not input:match('%.%.'), 'input must be project-relative')
local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local probe = [[
gem 'bigdecimal', '3.1.5'
require 'bigdecimal'
require 'fiddle'
LIBC_STRTOD = Fiddle::Function.new(Fiddle::Handle::DEFAULT['strtod'],
  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_DOUBLE)
def word_snapshot(value)
  value.nan? ? 'nan' : [value].pack('G').unpack('NN').join(':')
end
def ieee_decimal(coefficient, scale)
  coefficient = coefficient.sub(/\A0+/, '')
  return 0.0 if coefficient.empty?
  exponent = coefficient.length - scale - 1
  return Float::INFINITY if exponent >= 309
  return 0.0 if exponent < -324
  exact = Rational(Integer(coefficient), 10**scale)
  overflow_midpoint = (1 << 1024) - (1 << 970)
  candidate = LIBC_STRTOD.call(coefficient + 'e-' + scale.to_s, 0)
  # libc is only a starting point. Exact rational midpoint comparisons verify
  # the selected result independently of either decimal parser's rounding.
  loop do
    if candidate.infinite?
      return candidate if exact >= overflow_midpoint
      candidate = Float::MAX
      next
    end
    lower = candidate.zero? ? 0 : (candidate.to_r + candidate.prev_float.to_r) / 2
    upper = candidate.next_float.infinite? ? overflow_midpoint : (candidate.to_r + candidate.next_float.to_r) / 2
    even = [candidate].pack('G').unpack('NN').last.even?
    if exact < lower || (exact == lower && !even)
      candidate = candidate.prev_float
    elsif exact > upper || (exact == upper && !even)
      candidate = candidate.next_float
    else
      return candidate
    end
  end
end
File.foreach(ENV.fetch('BINARY64_INPUT')) do |line|
  id, op, ah, al, bh, bl = line.split
  if op == 'from_decimal' || op == 'from_ruby_decimal'
    source = (ah == '-' ? '-' : '') + al + 'e-' + bh
    ruby_decimal, ruby_text = BigDecimal(source).to_f, Float(source)
    if op == 'from_ruby_decimal'
      puts "#{id}\t#{word_snapshot(ruby_decimal)}"
      next
    end
    value = ieee_decimal(al, Integer(bh))
    value = -value if ah == '-'
    unless word_snapshot(ruby_decimal) == word_snapshot(value) && word_snapshot(ruby_text) == word_snapshot(value)
      puts "!profile\t#{id}\t#{word_snapshot(ruby_decimal)}\t#{word_snapshot(ruby_text)}\t#{word_snapshot(value)}"
    end
    puts "#{id}\t#{word_snapshot(value)}"
    next
  end
  a = [Integer(ah), Integer(al)].pack('NN').unpack1('G')
  b = [Integer(bh), Integer(bl)].pack('NN').unpack1('G')
  if op == 'format'
    puts "#{id}\t#{a.to_s}"
    next
  end
  if op == 'to_exact'
    if a.nan?
      snapshot = 'nan'
    elsif a.infinite?
      snapshot = a.negative? ? 'negative-infinity' : 'positive-infinity'
    else
      rational = a.abs.to_r
      scale = rational.denominator.bit_length - 1
      coefficient = rational.numerator * 5**scale
      while scale > 0 && coefficient % 10 == 0
        coefficient /= 10
        scale -= 1
      end
      scale = 0 if coefficient == 0
      snapshot = "finite:#{(Integer(ah) & 0x80000000) == 0 ? '+' : '-'}#{coefficient}:#{scale}"
    end
    puts "#{id}\t#{snapshot}"
    next
  end
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
  when 'exact_roundtrip' then a
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
local expected, observations = {}, {'id\tbigdecimal_to_f\tfloat_text\tieee_nearest_even\n'}
for line in result:gmatch('[^\n]+') do
  if line:sub(1,9) == '!profile\t' then observations[#observations+1] = line:sub(10)..'\n'
  else expected[#expected+1] = line..'\n' end
end
local f = assert(io.open(output, 'w')); assert(f:write(table.concat(expected))); assert(f:close())
f = assert(io.open(output..'.reference-differences.tsv', 'w')); assert(f:write(table.concat(observations))); assert(f:close())
