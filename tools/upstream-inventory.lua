-- Source inventory, not a claim of runtime parity or test coverage.
local root = assert(arg[1], 'usage: lua tools/upstream-inventory.lua UPSTREAM_ROOT')
local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local pipe = assert(io.popen('git -C ' .. quote(root) .. ' ls-files spec'))
local paths = {}
for path in pipe:lines() do
  if path:match('_spec%.rb$') then paths[#paths + 1] = path end
end
assert(pipe:close(), 'upstream git listing failed')
table.sort(paths)
local partial = {
  ['token_spec.rb']=true, ['token_matcher_spec.rb']=true, ['addition_spec.rb']=true, ['arithmetic_spec.rb']=true,
  ['division_spec.rb']=true, ['numeric_spec.rb']=true, ['numeric_parser_spec.rb']=true,
  ['comparator_spec.rb']=true,
  ['and_spec.rb']=true, ['identifiers_spec.rb']=true,
  ['and_function_spec.rb']=true, ['or_spec.rb']=true, ['xor_spec.rb']=true,
  ['min_spec.rb']=true, ['max_spec.rb']=true, ['avg_spec.rb']=true,
  ['abs_spec.rb']=true, ['mul_spec.rb']=true, ['count_spec.rb']=true,
  ['string_functions_spec.rb']=true, ['switch_spec.rb']=true,
  ['case_spec.rb']=true,
  ['round_spec.rb']=true, ['roundup_spec.rb']=true, ['rounddown_spec.rb']=true,
  ['sum_spec.rb']=true, ['negation_spec.rb']=true,
  ['parser_spec.rb']=true, ['tokenizer_spec.rb']=true,
  ['case_sensitivity_spec.rb']=true, ['calculator_spec.rb']=true,
  ['map_spec.rb']=true, ['filter_spec.rb']=true, ['all_spec.rb']=true,
  ['any_spec.rb']=true, ['reduce_spec.rb']=true, ['pluck_spec.rb']=true,
  ['member_access_spec.rb']=true, ['dependency_resolver_spec.rb']=true,
}
print('source\tdeclared_example_lines\tbend_parity_status')
for _, path in ipairs(paths) do
  local file = assert(io.open(root .. '/' .. path, 'r'))
  local count = 0
  for line in file:lines() do
    if line:match('^%s*it[%s%(]') or line:match('^%s*specify[%s%(]') then
      count = count + 1
    end
  end
  file:close()
  local name = path:match('([^/]+)$')
  print(('%s\t%d\t%s'):format(path, count, partial[name] and 'partial' or 'unassessed'))
end
