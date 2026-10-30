import Base

# Coordinates are zero-based. Relative axes store signed offsets from the cell
# containing the formula, so copying requires no rewriting of the address.
type Axis is Data:
  Fixed{index: Nat}
  Displaced{backward: Bool, distance: Nat}

type Notation is Data:
  A1Style{}
  R1C1Style{}

type Address is Data:
  AddressCell{row: Axis, column: Axis, notation: Notation}

type ParsedAxis is Data:
  GoodAxis{axis: Axis}
  BadAxis{message: String}

type ParsedAddress is Data:
  GoodAddress{address: Address}
  BadAddress{message: String}

def displacement(index: Nat, origin: Nat, before: Bool) -> Axis:
  match before:
    case True{}:
      Displaced{True{}, Nat.sub(origin, index)}
    case False{}:
      Displaced{False{}, Nat.sub(index, origin)}

def a1_axis(locked: Bool, +one_based: Nat, +origin: Nat) -> Axis:
  match locked:
    case True{}:
      Fixed{Nat.sub(one_based, 1n)}
    case False{}:
      displacement(Nat.sub(one_based, 1n), origin, Nat.is_le(one_based, origin))

type A1State is Data:
  Column{locked: Bool, number: Nat}
  Row{column_locked: Bool, column: Nat, row_locked: Bool, number: Nat}
  InvalidAddress{}

def bounded_state(valid: Bool, next: A1State) -> A1State:
  match valid:
    case True{}:
      next
    case False{}:
      InvalidAddress{}

def a1_digit(state: A1State, +digit: Nat) -> A1State:
  match state:
    case Column{locked, column}:
      Row{locked, column, False{}, digit}
    case Row{cl, col, rl, n}:
      +next = Nat.add(Nat.mul(n, 10n), digit)
      bounded_state(Nat.is_le(next, 4294967295n), Row{cl, col, rl, next})
    case InvalidAddress{}:
      InvalidAddress{}

def a1_letter(state: A1State, digit: Nat) -> A1State:
  match state:
    case Column{locked, n}:
      +next = Nat.add(Nat.mul(n, 26n), digit)
      bounded_state(Nat.is_le(next, 4294967295n), Column{locked, next})
    case state:
      InvalidAddress{}

def a1_dollar(state: A1State) -> A1State:
  match state:
    case Column{False{}, 0n}:
      Column{True{}, 0n}
    case Column{locked, 1n+p}:
      Row{locked, 1n+p, True{}, 0n}
    case state:
      InvalidAddress{}

def a1_classified(is_digit: Bool, is_letter: Bool, +code: U32, +state: A1State) -> A1State:
  match is_digit is_letter:
    case True{} letter:
      a1_digit(state, U32.to_nat(U32.sub(code, 48)))
    case False{} True{}:
      a1_letter(state, U32.to_nat(U32.sub(code, 64)))
    case False{} False{}:
      InvalidAddress{}

def a1_step(c: Char, state: A1State) -> A1State:
  match c:
    case Chr{36}:
      a1_dollar(state)
    case Chr{+code}:
      a1_classified(Char.is_digit(Chr{code}), Char.is_upper(Chr{code}), code, state)

def a1_scan(source: String, state: A1State) -> A1State:
  match source:
    case SNil{}:
      state
    case SCon{c, rest}:
      a1_scan(rest, a1_step(c, state))

def a1_finish(state: A1State, origin_row: Nat, origin_column: Nat) -> ParsedAddress:
  match state:
    case Row{cl, 1n+col, rl, 1n+row}:
      GoodAddress{AddressCell{a1_axis(rl, 1n+row, origin_row), a1_axis(cl, 1n+col, origin_column), A1Style{}}}
    case state:
      BadAddress{"Invalid A1 address"}

def parse_a1(source: String, origin_row: Nat, origin_column: Nat) -> ParsedAddress:
  a1_finish(a1_scan(String.to_upper(source), Column{False{}, 0n}), origin_row, origin_column)

# An axis is either an absolute one-based index or a bracketed signed offset.
def axis_finish(relative: Bool, negative: Bool, seen: Bool, number: Nat) -> ParsedAxis:
  match relative seen number:
    case True{} True{} n:
      GoodAxis{Displaced{negative, n}}
    case False{} True{} 1n+p:
      GoodAxis{Fixed{p}}
    case relative seen n:
      BadAxis{"Invalid R1C1 axis"}

def axis_digit(valid: Bool, n: Nat, next: Nat -> ParsedAxis) -> ParsedAxis:
  match valid:
    case True{}:
      next(n)
    case False{}:
      BadAxis{"Invalid R1C1 axis"}

def axis_scan(source: String, +n: Nat, +relative: Bool, +negative: Bool, seen: Bool) -> ParsedAxis:
  match source:
    case SNil{}:
      axis_finish(False{}, negative, Bool.and(seen, Bool.not(relative)), n)
    case SCon{Chr{93}, SNil{}}:
      axis_finish(True{}, negative, Bool.and(seen, relative), n)
    case SCon{Chr{+code}, rest}:
      +value = Nat.add(Nat.mul(n, 10n), U32.to_nat(U32.sub(code, 48)))
      axis_digit(Bool.and(Char.is_digit(Chr{code}), Nat.is_le(value, 4294967295n)), value, v => axis_scan(rest, v, relative, negative, True{}))

def parse_axis(source: String) -> ParsedAxis:
  match source:
    case SNil{}:
      GoodAxis{Displaced{False{}, 0n}}
    case SCon{Chr{91}, SCon{Chr{45}, rest}}:
      axis_scan(rest, 0n, True{}, True{}, False{})
    case SCon{Chr{91}, SCon{Chr{43}, rest}}:
      axis_scan(rest, 0n, True{}, False{}, False{})
    case SCon{Chr{91}, rest}:
      axis_scan(rest, 0n, True{}, False{}, False{})
    case source:
      axis_scan(source, 0n, False{}, False{}, False{})

def join_axes(row: ParsedAxis, column: ParsedAxis) -> ParsedAddress:
  match row column:
    case GoodAxis{r} GoodAxis{c}:
      GoodAddress{AddressCell{r, c, R1C1Style{}}}
    case BadAxis{e} column:
      BadAddress{e}
    case row BadAxis{e}:
      BadAddress{e}

def rc_parts(parts: List<&2, String>) -> ParsedAddress:
  match parts:
    case SCon{Chr{82}, row} <> column <> Nil{}:
      join_axes(parse_axis(row), parse_axis(column))
    case parts:
      BadAddress{"Invalid R1C1 address"}

def parse_r1c1(source: String) -> ParsedAddress:
  rc_parts(String.split(String.to_upper(source), 'C'))

def coordinate(valid: Bool, index: Nat) -> Maybe<&2, Nat>:
  match valid:
    case True{}:
      Some{index}
    case False{}:
      None{}

def resolve_axis(axis: Axis, +origin: Nat, +limit: Nat) -> Maybe<&2, Nat>:
  match axis:
    case Fixed{+index}:
      coordinate(Nat.is_lt(index, limit), index)
    case Displaced{True{}, +distance}:
      +index = Nat.sub(origin, distance)
      coordinate(Bool.and(Nat.is_ge(origin, distance), Nat.is_lt(index, limit)), index)
    case Displaced{False{}, distance}:
      +index = Nat.add(origin, distance)
      coordinate(Nat.is_lt(index, limit), index)

type Resolved is Data:
  At{row: Nat, column: Nat}
  ReferenceError{}

def resolved_axes(row: Maybe<&2, Nat>, column: Maybe<&2, Nat>) -> Resolved:
  match row column:
    case Some{r} Some{c}:
      At{r, c}
    case row column:
      ReferenceError{}

def resolve(address: Address, row: Nat, column: Nat, rows: Nat, columns: Nat) -> Resolved:
  match address:
    case AddressCell{r, c, style}:
      rr cc = resolve_axis(r, row, rows) resolve_axis(c, column, columns)
      resolved_axes(rr, cc)

def resolve_parsed(parsed: ParsedAddress, row: Nat, column: Nat, rows: Nat, columns: Nat) -> Resolved:
  match parsed:
    case GoodAddress{address}:
      resolve(address, row, column, rows, columns)
    case BadAddress{e}:
      ReferenceError{}

def letters_next(next: Nat, character: Char, prefix: Nat -> String) -> String:
  match next:
    case 0n:
      SCon{character, SNil{}}
    case 1n+p:
      prefix(1n+p) ++ SCon{character, SNil{}}

def letters(fuel: Nat, one_based: Nat) -> String:
  match fuel:
    case 0n:
      "?"
    case 1n+p:
      +n = Nat.sub(one_based, 1n)
      letters_next(Nat.div(n, 26n), Chr{U32.add(65, U32.from_nat(Nat.mod(n, 26n)))}, next => letters(p, next))

def column_text(axis: Axis, +column: Nat) -> String:
  match axis:
    case Fixed{n}:
      "$" ++ letters(1n+column, 1n+column)
    case Displaced{sign, n}:
      letters(1n+column, 1n+column)

def row_text(axis: Axis, row: Nat) -> String:
  match axis:
    case Fixed{n}:
      "$" ++ Nat.show(1n+row)
    case Displaced{sign, n}:
      Nat.show(1n+row)

def a1_resolved(resolved: Resolved, row: Axis, column: Axis) -> String:
  match resolved:
    case At{r, c}:
      column_text(column, c) ++ row_text(row, r)
    case ReferenceError{}:
      "#REF!"

def render_a1(address: Address, row: Nat, column: Nat, rows: Nat, columns: Nat) -> String:
  match address:
    case AddressCell{+r, +c, style}:
      a1_resolved(resolve(AddressCell{r, c, A1Style{}}, row, column, rows, columns), r, c)

def rc_axis(axis: Axis) -> String:
  match axis:
    case Fixed{n}:
      Nat.show(1n+n)
    case Displaced{sign, 0n}:
      ""
    case Displaced{False{}, 1n+p}:
      "[" ++ Nat.show(1n+p) ++ "]"
    case Displaced{True{}, 1n+p}:
      "[-" ++ Nat.show(1n+p) ++ "]"

def render_r1c1(address: Address) -> String:
  match address:
    case AddressCell{r, c, style}:
      "R" ++ rc_axis(r) ++ "C" ++ rc_axis(c)

def render_parsed_a1(parsed: ParsedAddress, row: Nat, column: Nat, rows: Nat, columns: Nat) -> String:
  match parsed:
    case GoodAddress{address}:
      render_a1(address, row, column, rows, columns)
    case BadAddress{e}:
      "#REF!"

def render_parsed_r1c1(parsed: ParsedAddress) -> String:
  match parsed:
    case GoodAddress{address}:
      render_r1c1(address)
    case BadAddress{e}:
      "#REF!"
