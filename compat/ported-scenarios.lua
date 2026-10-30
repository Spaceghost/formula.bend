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
  ['spec/numeric_parser_spec.rb'] = {
    {'casts a String to an Integer if possible', {'coerce_integer_string', 'coerce_class_integer_string'}},
    {'casts a String to a BigDecimal if possible and if Integer would loose information', {'coerce_decimal_string', 'coerce_class_decimal_string'}},
    {'casts a String to a BigDecimal with a negative number', {'coerce_negative_decimal_string', 'coerce_class_negative_decimal_string'}},
    {'casts a String to a BigDecimal without a leading zero', {'coerce_negative_fraction_string', 'coerce_class_negative_fraction_string'}},
    {'casts a String with Sientific notiation to a BigDecimal', {'coerce_scientific_string', 'coerce_class_scientific_string'}},
    {'casts a String with negative Sientific notiation to a BigDecimal', {'coerce_negative_exponent_string', 'coerce_class_negative_exponent_string'}},
    {'casts a String with hexadecimal to an Integer', {'coerce_hex_string', 'coerce_class_hex_string', 'coerce_hex_zero_padded_string', 'coerce_class_hex_zero_padded_string'}},
    {'casts a String with a negative hexadecimal to an Integer', {'coerce_negative_hex_string', 'coerce_class_negative_hex_string'}},
    {'raises an error if the value could not be cast to a Numeric', {'coerce_invalid_word', 'coerce_bare_minus', 'coerce_empty_string', 'coerce_null', 'coerce_trailing_dot', 'coerce_boolean', 'coerce_expression', 'coerce_array', 'coerce_suffix'}},
  },
}
