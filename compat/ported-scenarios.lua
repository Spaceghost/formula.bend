-- Scenario correspondence, not a claim that the complete upstream suite passes.
-- COUNT's Float input is represented as exact decimal 2.3 in Bend; COUNT only
-- inspects its length capability, so this adaptation does not alter the result.
return {
  ['spec/ast/count_spec.rb'] = {
    {'returns the length of an array', 'upstream_count_three'},
    {'returns the length of a single number object', 'upstream_count_number'},
    {'returns the length if a single String is passed', 'upstream_count_string'},
    {'returns the length if an array is passed', 'upstream_count_array'},
    {'returns the length if an array with one element is passed', 'upstream_count_array_one'},
    {'returns the length if an array even if it has nested array', 'upstream_count_array_among_args'},
    {'returns the length if an array is passed', 'count_zero'},
  },
}
