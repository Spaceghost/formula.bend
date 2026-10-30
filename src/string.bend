import Base

def take(count: Nat, text: String) -> String:
  match count text:
    case 0n text:
      SNil{}
    case 1n+p SCon{c, rest}:
      SCon{c, take(p, rest)}
    case count SNil{}:
      SNil{}

def drop(text: String, count: Nat) -> String:
  match text count:
    case text 0n:
      text
    case SCon{c, rest} 1n+p:
      drop(rest, p)
    case SNil{} count:
      SNil{}

def choose(chosen: Bool, yes: Unit -> String, no: Unit -> String) -> String:
  match chosen:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def hex_char(+n: U32) -> Char:
  Chr{Bool.pick(U32, U32.is_lt(n, 10), U32.add(48, n), U32.add(55, n))}

def escaped_control(control: Bool, +c: Char, rest: String) -> String:
  match control:
    case True{}:
      "\\u00" ++ SCon{hex_char(U32.div(Char.to_u32(c), 16)), SCon{hex_char(U32.mod(Char.to_u32(c), 16)), rest}}
    case False{}:
      SCon{c, rest}

def escaped(text: String) -> String:
  match text:
    case SNil{}:
      SNil{}
    case SCon{Chr{34}, rest}:
      SCon{Chr{92}, SCon{Chr{34}, escaped(rest)}}
    case SCon{Chr{92}, rest}:
      SCon{Chr{92}, SCon{Chr{92}, escaped(rest)}}
    case SCon{Chr{10}, rest}:
      SCon{Chr{92}, SCon{Chr{110}, escaped(rest)}}
    case SCon{Chr{13}, rest}:
      SCon{Chr{92}, SCon{Chr{114}, escaped(rest)}}
    case SCon{Chr{9}, rest}:
      SCon{Chr{92}, SCon{Chr{116}, escaped(rest)}}
    case SCon{Chr{7}, rest}:
      SCon{Chr{92}, SCon{Chr{97}, escaped(rest)}}
    case SCon{Chr{8}, rest}:
      SCon{Chr{92}, SCon{Chr{98}, escaped(rest)}}
    case SCon{Chr{27}, rest}:
      SCon{Chr{92}, SCon{Chr{101}, escaped(rest)}}
    case SCon{Chr{12}, rest}:
      SCon{Chr{92}, SCon{Chr{102}, escaped(rest)}}
    case SCon{Chr{11}, rest}:
      SCon{Chr{92}, SCon{Chr{118}, escaped(rest)}}
    case SCon{Chr{35}, SCon{Chr{123}, rest}}:
      SCon{Chr{92}, SCon{Chr{35}, SCon{Chr{123}, escaped(rest)}}}
    case SCon{Chr{35}, SCon{Chr{36}, rest}}:
      SCon{Chr{92}, SCon{Chr{35}, SCon{Chr{36}, escaped(rest)}}}
    case SCon{Chr{35}, SCon{Chr{64}, rest}}:
      SCon{Chr{92}, SCon{Chr{35}, SCon{Chr{64}, escaped(rest)}}}
    case SCon{+c, rest}:
      escaped_control(Bool.or(U32.is_lt(Char.to_u32(c), 32), U32.is_eq(Char.to_u32(c), 127)), c, escaped(rest))

def quote(text: String) -> String:
  "\"" ++ escaped(text) ++ "\""

def replacement_capture(digit: Bool, c: Char, rest: Unit -> String) -> String:
  match digit:
    case True{}:
      rest(Unit{})
    case False{}:
      SCon{Chr{92}, SCon{c, rest(Unit{})}}

def expand_replacement(replacement: String, +matched: String, +before: String, +after: String) -> String:
  match replacement:
    case SNil{}:
      SNil{}
    case SCon{Chr{92}, SCon{Chr{38}, rest}}:
      matched ++ expand_replacement(rest, matched, before, after)
    case SCon{Chr{92}, SCon{Chr{48}, rest}}:
      matched ++ expand_replacement(rest, matched, before, after)
    case SCon{Chr{92}, SCon{Chr{96}, rest}}:
      before ++ expand_replacement(rest, matched, before, after)
    case SCon{Chr{92}, SCon{Chr{39}, rest}}:
      after ++ expand_replacement(rest, matched, before, after)
    case SCon{Chr{92}, SCon{Chr{43}, rest}}:
      expand_replacement(rest, matched, before, after)
    case SCon{Chr{92}, SCon{Chr{92}, rest}}:
      SCon{Chr{92}, expand_replacement(rest, matched, before, after)}
    case SCon{Chr{92}, SCon{+c, rest}}:
      replacement_capture(Char.is_digit(c), c, u => expand_replacement(rest, matched, before, after))
    case SCon{c, rest}:
      SCon{c, expand_replacement(rest, matched, before, after)}

def substitute_at(+text: String, +needle: String, replacement: String, reversed_prefix: String) -> String:
  +before = String.reverse(reversed_prefix)
  +after = drop(text, String.length(needle))
  before ++ expand_replacement(replacement, needle, before, after) ++ after

def substitute(text: String, +needle: String, +replacement: String, +reversed_prefix: String) -> String:
  match text:
    case SNil{}:
      choose(String.eq(needle, ""), u => substitute_at("", needle, replacement, reversed_prefix), u => String.reverse(reversed_prefix))
    case SCon{+c, +rest}:
      choose(String.starts_with(SCon{c, rest}, needle), u => substitute_at(SCon{c, rest}, needle, replacement, reversed_prefix), u => substitute(rest, needle, replacement, SCon{c, reversed_prefix}))

def find_result(found: Bool, position: Nat, next: Unit -> Maybe<&2, Nat>) -> Maybe<&2, Nat>:
  match found:
    case True{}:
      Some{position}
    case False{}:
      next(Unit{})

def find(text: String, +needle: String, +position: Nat) -> Maybe<&2, Nat>:
  match text:
    case SNil{}:
      Bool.pick(Maybe<&2, Nat>, String.eq(needle, ""), Some{position}, None{})
    case SCon{c, +rest}:
      find_result(String.starts_with(SCon{c, rest}, needle), position, u => find(rest, needle, 1n+position))

