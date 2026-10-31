-- Canonicalize the String form of Ruby Integer(value), whose default base is
-- inferred from prefixes (including legacy leading-zero octal). No Lua number
-- holds the complete value: nondecimal inputs accumulate decimal digits.
local M = {}
local bases = {['0x']=16, ['0b']=2, ['0o']=8, ['0d']=10}
local function digit(byte)
  if byte >= 48 and byte <= 57 then return byte - 48 end
  if byte >= 65 and byte <= 70 then return byte - 55 end
  if byte >= 97 and byte <= 102 then return byte - 87 end
end
local function multiply_add(digits, base, carry)
  for i = 1, #digits do
    local value = digits[i] * base + carry
    digits[i], carry = value % 10, value // 10
  end
  while carry > 0 do
    digits[#digits + 1], carry = carry % 10, carry // 10
  end
end
function M.canonical(raw)
  assert(type(raw) == 'string', 'typed integer payload must be a string')
  local text = raw:gsub('^[\t\n\v\f\r ]+', ''):gsub('[\t\n\v\f\r ]+$', '')
  local negative = text:sub(1, 1) == '-'
  if negative or text:sub(1, 1) == '+' then text = text:sub(2) end
  assert(#text > 0, 'invalid typed integer: missing digits')
  local base = 10
  local prefix = text:sub(1, 2):lower()
  local explicit = bases[prefix]
  if explicit then
    base, text = explicit, text:sub(3)
  elseif #text > 1 and text:sub(1, 1) == '0' then
    base = 8
  end
  assert(#text > 0, 'invalid typed integer: missing digits')
  local previous_digit = false
  local decimal, converted = {}, {0}
  for i = 1, #text do
    local byte = text:byte(i)
    if byte == 95 then
      local following = i < #text and digit(text:byte(i + 1))
      assert(previous_digit and following and following < base,
        'invalid typed integer: misplaced underscore')
      previous_digit = false
    else
      local value = digit(byte)
      assert(value and value < base, 'invalid typed integer: invalid digit')
      previous_digit = true
      if base == 10 then decimal[#decimal + 1] = string.char(byte)
      else multiply_add(converted, base, value) end
    end
  end
  local magnitude
  if base == 10 then
    magnitude = table.concat(decimal):gsub('^0+', '')
    if magnitude == '' then magnitude = '0' end
  else
    local parts = {}
    for i = #converted, 1, -1 do parts[#parts + 1] = tostring(converted[i]) end
    magnitude = table.concat(parts)
  end
  return negative and magnitude ~= '0' and '-' .. magnitude or magnitude
end
return M
