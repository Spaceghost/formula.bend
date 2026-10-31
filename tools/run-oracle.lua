-- Reference-only probe: no Ruby code is used by the Bend application.
local project = assert(arg[1], 'usage: lua tools/run-oracle.lua PROJECT UPSTREAM GEMS STORAGE RUNROOT OUTPUT [CORPUS_RELATIVE_PATH]')
local upstream = assert(arg[2], 'missing upstream directory')
local gems = assert(arg[3], 'missing gems directory')
local storage = assert(arg[4], 'missing container storage directory')
local runroot = assert(arg[5], 'missing container runroot')
local output = assert(arg[6], 'missing output file')
local corpus = arg[7] or 'build/scalar-corpus.formulas.tsv'
assert(not corpus:match('^/') and not corpus:match('%.%.'), 'corpus path must be relative to the project')
local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function command(args)
  local escaped = {}
  for i, value in ipairs(args) do escaped[i] = quote(value) end
  return table.concat(escaped, ' ')
end
local probe = [[
def context_value(value)
  case value
  when Array then value.map { |item| context_value(item) }
  when Hash
    return value.fetch('text') if value.key?('text')
    return value.fetch('symbol').to_sym if value.key?('symbol')
    if value.key?('class') || value.key?('module')
      kind = value.key?('class') ? 'class' : 'module'
      name = value.fetch(kind)
      reference = Object.const_get(name)
      raise 'noncanonical named reference' unless reference.name == name
      raise 'wrong named reference kind' unless kind == (reference.is_a?(Class) ? 'class' : 'module')
      raise 'wrong named ancestry' unless reference.ancestors.drop(1).map(&:name) == value.fetch('ancestors')
      return reference
    end
    return value.fetch('hash').map { |key, item| [context_value(key), context_value(item)] }.to_h if value.key?('hash')
    return Integer(value.fetch('integer')) if value.key?('integer')
    return BigDecimal(value.fetch('decimal')) if value.key?('decimal')
    raise 'unhandled context value'
  else value
  end
end
def error_factory(factory, input)
  begin
    error = case factory
    when 'parse' then Dentaku::ParseError.for(input[:reason], **input.fetch(:meta))
    when 'tokenizer' then Dentaku::TokenizerError.for(input[:reason], **input.fetch(:meta))
    when 'argument' then Dentaku::ArgumentError.for(input[:reason], **input.fetch(:meta))
    when 'unbound' then Dentaku::UnboundVariableError.new(input[:variables])
    when 'math_domain' then Dentaku::MathDomainError.new(input[:function_name], input[:args])
    when 'node' then Dentaku::NodeError.new(input[:expected], input[:actual], input[:operand])
    when 'zero_division' then Dentaku::ZeroDivisionError.new
    else Dentaku::BaseError.new
    end
  rescue ::ArgumentError => error
    # Invalid factory reasons deliberately raise a native ArgumentError.
  end
  error = error.exception(input[:override_message]) if input.key?(:override_message)
  error.assigned_to = input[:assigned_to] if input.key?(:assigned_to)
  attributes = {}
  %i[unbound_variables function_name args expected actual operand reason meta].each do |name|
    attributes[name] = error.public_send(name) if error.respond_to?(name)
  end
  {'class' => error.class.name, 'message' => error.message,
   'dentaku_error' => error.is_a?(Dentaku::Error),
   'argument_error' => error.is_a?(::ArgumentError),
   'zero_division_error' => error.is_a?(::ZeroDivisionError),
   'attributes' => attributes,
   'assigned_to' => error.respond_to?(:assigned_to) ? error.assigned_to : nil}
end
def snapshot_value(value)
  case value
  when nil then 'null'
  when true, false then "boolean:#{value}"
  when BigDecimal then "number:#{value.to_s('F').sub(/\.0+\z/, '')}"
  when Integer then "number:#{value}"
  when String then "string:#{value}"
  when Symbol then "symbol:#{value}"
  when Class then "class-reference:#{value.name}"
  when Module then "module-reference:#{value.name}"
  when Hash
    parts = value.flat_map { |key, item| [snapshot_value(key), snapshot_value(item)] }
    "hash:{#{parts.map { |part| "#{part.length}:#{part}" }.join}}"
  when Array
    parts = value.map { |item| snapshot_value(item) }
    "array:[#{parts.map { |part| "#{part.length}:#{part}" }.join}]"
  else raise "unhandled oracle type #{value.class}"
  end
end
require 'dentaku/token_matcher'
def matcher_construct(data)
  matcher = if data[:builtin]
    data[:builtin] == 'function' ? Dentaku::TokenMatcher.function(data[:values]) : Dentaku::TokenMatcher.public_send(data[:builtin])
  else
    Dentaku::TokenMatcher.new(data[:categories], data[:values], (data[:children] || []).map { |child| child && matcher_construct(child) })
  end
  (data[:alternatives] || []).each { |other| matcher = matcher | matcher_construct(other) }
  (data[:modifiers] || []).each { |modifier| matcher.public_send(modifier) }
  matcher
end
def matcher_token(data)
  data && Dentaku::Token.new(data[:category], data[:value], data[:raw_value])
end
def matcher_token_snapshot(token)
  {'category'=>token.category,'value'=>token.value,'raw_value'=>token.raw_value,
   'to_s'=>token.to_s,'length'=>token.length,'empty'=>token.empty?,
   'operator'=>token.operator?,'grouping'=>token.grouping?,
   'open'=>token.open?,'close'=>token.close?}
end
File.foreach(ENV.fetch('FORMULA_ORACLE_CORPUS')) do |line|
  id, source, operation, encoded_context, sensitive, source_format = line.chomp.split("\t", 6)
  source = JSON.parse(source) if source_format == 'json'
  operation ||= 'evaluate'
  json_output = operation.start_with?('json_')
  operation = operation.delete_prefix('json_') if json_output
  begin
    raw_context = JSON.parse(encoded_context || '{}')
    context = if raw_context.key?('bindings')
      raw_context.fetch('bindings').map { |key, item| [context_value(key), context_value(item)] }.to_h
    else
      raw_context.transform_values { |item| context_value(item) }
    end
    calculator = Dentaku::Calculator.new(case_sensitive: sensitive == 'true')
    value = case operation
    when 'token_matcher'
      input = context.fetch('input')
      matcher = matcher_construct(input[:matcher])
      case source
      when 'accept' then matcher == matcher_token(input[:token])
      when 'match'
        accepted, tokens = matcher.match(input[:stream].map { |data| matcher_token(data) }, input.fetch(:offset, 0))
        [accepted, tokens.map { |token| matcher_token_snapshot(token) }]
      else
        {'categories'=>matcher.categories.keys,'values'=>matcher.values.keys,'leaf'=>matcher.leaf_matcher?, 'caret'=>matcher.caret?,
         'minimum'=>matcher.instance_variable_get(:@min),
         'maximum'=>matcher.instance_variable_get(:@max).infinite? ? 'infinity' : 1}
      end
    when 'token'
      make_token = ->(data) { Dentaku::Token.new(data[:category], data[:value], data[:raw_value]) }
      input = context.fetch('input')
      if source == 'equal'
        make_token.call(input[:left]) == make_token.call(input[:right])
      elsif source == 'is'
        make_token.call(input[:token]).is?(input[:expected])
      else
        token = make_token.call(input)
        {'category'=>token.category,'value'=>token.value,'raw_value'=>token.raw_value,
         'to_s'=>token.to_s,'length'=>token.length,'empty'=>token.empty?,
         'operator'=>token.operator?,'grouping'=>token.grouping?,
         'open'=>token.open?,'close'=>token.close?}
      end
    when 'error_factory' then error_factory(source, context.fetch('input'))
    when 'resolve_order' then Dentaku::DependencyResolver.find_resolve_order(context.fetch('input'), sensitive == 'true')
    when 'resolve_cycles' then Dentaku::DependencyResolver.cycles(context.fetch('input'), sensitive == 'true')
    when 'identifiers' then calculator.identifiers(source)
    when 'dependencies' then calculator.dependencies(source, context)
    when 'coerce', 'coerce_class', 'coerce_message' then Dentaku::NumericParser.ensure_numeric!(context.fetch('input'))
    when 'type' then calculator.ast(source).type
    when 'permissive' then calculator.evaluate(source, context)
    else calculator.evaluate!(source, context)
    end
    snapshot = case operation
    when 'identifiers', 'dependencies' then "names:#{value.join(',')}"
    when 'class', 'coerce_class' then "class:#{value.class.name}"
    when 'type' then "type:#{value || 'nil'}"
    when 'message', 'coerce_message' then 'no-error'
    else snapshot_value(value)
    end
  rescue Dentaku::Error => error
    snapshot = ['message', 'coerce_message'].include?(operation) ? "message:#{error.message}" : "error:#{error.class.name}"
  rescue TSort::Cyclic => error
    raise unless ['resolve_order', 'resolve_cycles'].include?(operation)
    snapshot = "error:#{error.class.name}"
  rescue RangeError => error
    # These source operations leak native Ruby range failures in this baseline.
    raise unless error.message.include?('too big to convert') || error.message == 'shift width too big'
    snapshot = ['message', 'coerce_message'].include?(operation) ? "message:#{error.message}" : "error:#{error.class.name}"
  end
  snapshot = "json:#{JSON.generate(snapshot)}" if json_output
  puts "#{id}\t#{snapshot}"
end
]]
local args = {
  'podman','--root',storage,'--runroot',runroot,'run','--rm',
  '--cgroups=disabled','--network=host','--security-opt','label=disable',
  '-e','GEM_HOME=/gems','-e','GEM_PATH=/gems',
  '-e','FORMULA_ORACLE_CORPUS=/formula/' .. corpus,
  '-v',gems .. ':/gems','-v',upstream .. ':/reference:ro',
  '-v',project .. ':/formula:ro','-w','/reference',
  os.getenv('FORMULA_REFERENCE_IMAGE') or 'localhost/formula-dentaku-reference:3.3.13',
  'ruby','-Ilib','-rdentaku','-rjson','-e',probe,
}
local pipe = assert(io.popen(command(args), 'r'))
local result = assert(pipe:read('*a'))
local ok, _, code = pipe:close()
assert(ok, 'oracle failed; output was not replaced (exit ' .. tostring(code) .. ')')
local file = assert(io.open(output, 'w'))
file:write(result); file:close()
