local cases = dofile(arg[1] or 'compat/scalar-cases.lua')
local mappings = dofile(arg[2] or 'compat/ported-scenarios.lua')
local by_id = {}
for _, case in ipairs(cases) do
  assert(not by_id[case.id], 'duplicate case id: ' .. case.id)
  by_id[case.id] = case
end
local count = 0
for path, scenarios in pairs(mappings) do
  assert(path:match('^spec/.*_spec%.rb$'), 'invalid upstream spec path: ' .. path)
  for _, scenario in ipairs(scenarios) do
    assert(type(scenario[1]) == 'string' and #scenario[1] > 0, 'missing scenario description')
    local ids = type(scenario[2]) == 'table' and scenario[2] or {scenario[2]}
    assert(#ids > 0, 'scenario has no differential cases: ' .. scenario[1])
    for _, id in ipairs(ids) do
      local case = assert(by_id[id], 'missing mapped case: ' .. tostring(id))
      assert(type(case.expected) == 'string' and #case.expected > 0, 'missing expected result: ' .. id)
    end
    count = count + 1
  end
end
print(count .. ' upstream scenario mappings reference existing differential cases')
