import Base
import ../src/core.bend as Core

# Fixture transport: n/t/f; s/y/i/d followed by codepoint length, ':' and text;
# a ... ] for arrays, h key value ... } for ordered hashes. Explicit ends keep
# parsing a structural fold over the input, with no recursion budget.
type Container is Data:
  ArrayContainer{}
  HashContainer{}

type Frame is Data:
  Open{kind: Container, reversed: List<&2, Core.Value>}

type Mode is Data:
  AwaitValue{}
  Length{tag: Char, value: Nat, seen: Bool}
  TextPayload{tag: Char, remaining: Nat, reversed: String}

type State is Data:
  Reading{mode: Mode, stack: List<&2, Frame>}
  Complete{value: Core.Value}
  Broken{message: String}

type Decoded is Data:
  Value{value: Core.Value}
  Invalid{message: String}

def accept(value: Core.Value, stack: List<&2, Frame>) -> State:
  match value stack:
    case Core.Failure{message} stack:
      Broken{message}
    case value Nil{}:
      Complete{value}
    case value Open{kind, reversed} <> rest:
      Reading{AwaitValue{}, Open{kind, value <> reversed} <> rest}

def array(values: List<&2, Core.Value>) -> Core.Value:
  match values:
    case Nil{}:
      Core.ArrayNil{}
    case head <> rest:
      Core.ArrayCons{head, array(rest)}

def hash(values: List<&2, Core.Value>) -> Core.Value:
  match values:
    case Nil{}:
      Core.HashNil{}
    case key <> value <> rest:
      Core.HashEntry{key, value, hash(rest)}
    case values:
      Core.Failure{"Odd number of hash fields in corpus input"}

def even_fields(values: List<&2, Core.Value>) -> Bool:
  match values:
    case Nil{}:
      True{}
    case key <> value <> rest:
      even_fields(rest)
    case values:
      False{}

def close_hash(valid: Bool, values: List<&2, Core.Value>, stack: List<&2, Frame>) -> State:
  match valid:
    case True{}:
      accept(hash(values), stack)
    case False{}:
      Broken{"Odd number of hash fields in corpus input"}

def close(stack: List<&2, Frame>, end: Char) -> State:
  match stack end:
    case Open{ArrayContainer{}, reversed} <> rest Chr{93}:
      accept(array(List.reverse(&2, Core.Value, reversed)), rest)
    case Open{HashContainer{}, reversed} <> rest Chr{125}:
      +values = List.reverse(&2, Core.Value, reversed)
      close_hash(even_fields(values), values, rest)
    case stack end:
      Broken{"Unmatched container end in corpus input"}

def integer(value: Core.Value) -> Core.Value:
  match value:
    case Core.Number{n}:
      Core.Number{n}
    case Core.IntegerNumber{n}:
      Core.IntegerNumber{n}
    case Core.NegativeInteger{n}:
      Core.NegativeInteger{n}
    case Core.Failure{message}:
      Core.Failure{message}
    case value:
      Core.Failure{"Non-integer corpus input"}

# This is typed BigDecimal input, not formula-string numeric coercion.
def decimal_space(c: Char) -> Bool:
  +code = Char.to_u32(c)
  Bool.or(U32.is_eq(code, 32), Bool.and(U32.is_ge(code, 9), U32.is_le(code, 13)))

def decimal_trim_left(text: String) -> String:
  match text:
    case SNil{}:
      SNil{}
    case SCon{+c, +rest}:
      Bool.pick(String, decimal_space(c), decimal_trim_left(rest), SCon{c, rest})

def decimal_magnitude(text: String) -> Core.Value:
  match text:
    case SCon{Chr{43}, rest}:
      Core.Failure{"Invalid decimal sign in corpus input"}
    case SCon{Chr{45}, rest}:
      Core.Failure{"Invalid decimal sign in corpus input"}
    case text:
      Core.decimal_result(Core.require_numeric(Core.TextValue{text}))

def decimal_signed(text: String) -> Core.Value:
  match text:
    case SCon{Chr{45}, rest}:
      Core.negate_value(decimal_magnitude(rest))
    case SCon{Chr{43}, rest}:
      decimal_magnitude(rest)
    case text:
      decimal_magnitude(text)

def decimal(text: String) -> Core.Value:
  decimal_signed(String.reverse(decimal_trim_left(String.reverse(decimal_trim_left(text)))))

def scalar(tag: Char, text: String) -> Core.Value:
  match tag:
    case Chr{115}:
      Core.TextValue{text}
    case Chr{121}:
      Core.SymbolValue{text}
    case Chr{105}:
      integer(Core.require_numeric(Core.TextValue{text}))
    case Chr{100}:
      decimal(text)
    case tag:
      Core.Failure{"Unknown scalar type in corpus input"}

def start_text(seen: Bool, tag: Char, length: Nat, stack: List<&2, Frame>) -> State:
  match seen length:
    case False{} length:
      Broken{"Missing text length in corpus input"}
    case True{} 0n:
      accept(scalar(tag, ""), stack)
    case True{} length:
      Reading{TextPayload{tag, length, ""}, stack}

def length_digit(fits: Bool, tag: Char, value: Nat, digit: Nat, stack: List<&2, Frame>) -> State:
  match fits:
    case False{}:
      Broken{"Text length exceeds corpus input"}
    case True{}:
      Reading{Length{tag, Nat.add(Nat.mul(value, 10n), digit), True{}}, stack}

def append_digit(valid: Bool, tag: Char, +value: Nat, +digit: Nat, +limit: Nat, stack: List<&2, Frame>) -> State:
  match valid:
    case False{}:
      Broken{"Invalid text length in corpus input"}
    case True{}:
      length_digit(Bool.or(Nat.is_lt(value, Nat.div(limit, 10n)), Bool.and(Nat.is_eq(value, Nat.div(limit, 10n)), Nat.is_le(digit, Nat.mod(limit, 10n)))), tag, value, digit, stack)

def length_step(tag: Char, value: Nat, seen: Bool, stack: List<&2, Frame>, +c: Char, limit: Nat) -> State:
  match c:
    case Chr{58}:
      start_text(seen, tag, value, stack)
    case c:
      +code = Char.to_u32(c)
      append_digit(Bool.and(U32.is_ge(code, 48), U32.is_le(code, 57)), tag, value, U32.to_nat(U32.sub(code, 48)), limit, stack)

def text_done(remaining: Nat, tag: Char, reversed: String, stack: List<&2, Frame>) -> State:
  match remaining:
    case 0n:
      accept(scalar(tag, String.reverse(reversed)), stack)
    case remaining:
      Reading{TextPayload{tag, remaining, reversed}, stack}

def text_step(remaining: Nat, tag: Char, reversed: String, stack: List<&2, Frame>, c: Char) -> State:
  match remaining:
    case 0n:
      Broken{"Invalid pending text in corpus input"}
    case 1n+p:
      text_done(p, tag, SCon{c, reversed}, stack)

def tag_step(+c: Char, stack: List<&2, Frame>) -> State:
  match c:
    case Chr{110}:
      accept(Core.NullValue{}, stack)
    case Chr{116}:
      accept(Core.Logical{True{}}, stack)
    case Chr{102}:
      accept(Core.Logical{False{}}, stack)
    case Chr{97}:
      Reading{AwaitValue{}, Open{ArrayContainer{}, Nil{}} <> stack}
    case Chr{104}:
      Reading{AwaitValue{}, Open{HashContainer{}, Nil{}} <> stack}
    case Chr{93}:
      close(stack, c)
    case Chr{125}:
      close(stack, c)
    case Chr{115}:
      Reading{Length{c, 0n, False{}}, stack}
    case Chr{121}:
      Reading{Length{c, 0n, False{}}, stack}
    case Chr{105}:
      Reading{Length{c, 0n, False{}}, stack}
    case Chr{100}:
      Reading{Length{c, 0n, False{}}, stack}
    case c:
      Bool.pick(State, Char.is_space(c), Reading{AwaitValue{}, stack}, Broken{"Unknown type in corpus input"})

def step(state: State, +c: Char, limit: Nat) -> State:
  match state:
    case Broken{message}:
      Broken{message}
    case Complete{value}:
      Bool.pick(State, Char.is_space(c), Complete{value}, Broken{"Trailing data in corpus input"})
    case Reading{AwaitValue{}, stack}:
      tag_step(c, stack)
    case Reading{Length{tag, value, seen}, stack}:
      length_step(tag, value, seen, stack, c, limit)
    case Reading{TextPayload{tag, remaining, reversed}, stack}:
      text_step(remaining, tag, reversed, stack, c)

def finish(state: State) -> Decoded:
  match state:
    case Complete{value}:
      Value{value}
    case Broken{message}:
      Invalid{message}
    case state:
      Invalid{"Incomplete corpus input"}

def read(source: String, +limit: Nat, state: State) -> Decoded:
  match source:
    case SNil{}:
      finish(state)
    case SCon{c, rest}:
      read(rest, limit, step(state, c, limit))

def decode(+source: String) -> Decoded:
  read(source, String.length(source), Reading{AwaitValue{}, Nil{}})
