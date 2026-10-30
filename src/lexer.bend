import Base
import ./decimal.bend as Decimal

type Token is Data:
  Integer{value: Nat}
  DecimalLiteral{value: Decimal.Decimal}
  Identifier{name: String}
  StringLiteral{value: String}
  Plus{}
  Minus{}
  Times{}
  Slash{}
  LParen{}
  RParen{}
  Comma{}
  EqualToken{}
  NotEqualToken{}
  LessToken{}
  LessEqualToken{}
  GreaterToken{}
  GreaterEqualToken{}
  AndWord{spelling: String}
  OrWord{spelling: String}
  XorWord{spelling: String}
  NotWord{spelling: String}
  BangWord{}
  Invalid{character: Char}

type Mode is Data:
  Idle{}
  Digits{reversed: List<&2, U32>}
  Fraction{reversed: List<&2, U32>, scale: Nat}
  Word{reversed: String}
  Quoted{quote: Char, reversed: String}
  Pending{symbol: Char}
  AliasPending{is_and: Bool}

type CharacterClass is Data:
  Digit{value: Nat, character: Char}
  Letter{character: Char}
  Space{}
  Symbol{character: Char}

def classify(+c: Char) -> CharacterClass:
  Bool.pick(CharacterClass, Char.is_digit(c), Digit{U32.to_nat(U32.sub(Char.to_u32(c), 48)), c}, Bool.pick(CharacterClass, Bool.or(Char.is_alpha(c), Char.is_eq(c, '_')), Letter{c}, Bool.pick(CharacterClass, Char.is_space(c), Space{}, Symbol{c})))

def integer_token(+digits: List<&2, U32>, small: Bool) -> Token:
  match small:
    case True{}:
      Integer{Decimal.coefficient(digits)}
    case False{}:
      DecimalLiteral{Decimal.Exact{digits, 0n}}

def symbol(c: Char) -> Token:
  match c:
    case Chr{33}:
      BangWord{}
    case Chr{61}:
      EqualToken{}
    case Chr{60}:
      LessToken{}
    case Chr{62}:
      GreaterToken{}
    case Chr{45}:
      Minus{}
    case Chr{43}:
      Plus{}
    case Chr{47}:
      Slash{}
    case Chr{42}:
      Times{}
    case Chr{40}:
      LParen{}
    case Chr{44}:
      Comma{}
    case Chr{41}:
      RParen{}
    case c:
      Invalid{c}

def flush(mode: Mode, tokens: List<&2, Token>) -> List<&2, Token>:
  match mode:
    case AliasPending{is_and}:
      Invalid{Chr{38}} <> tokens
    case Pending{c}:
      symbol(c) <> tokens
    case Quoted{quote, text}:
      Invalid{quote} <> tokens
    case Idle{}:
      tokens
    case Digits{+n}:
      integer_token(n, Nat.is_le(List.length(&2, U32, n), 3n)) <> tokens
    case Fraction{digits, 0n}:
      Invalid{Chr{46}} <> tokens
    case Fraction{digits, 1n+p}:
      DecimalLiteral{Decimal.Exact{digits, 1n+p}} <> tokens
    case Word{s}:
      Identifier{String.reverse(s)} <> tokens

def spaced_word(+text: String) -> Token:
  Bool.pick(Token, String.eq(String.to_lower(text), "and"), AndWord{text}, Bool.pick(Token, String.eq(String.to_lower(text), "or"), OrWord{text}, Bool.pick(Token, String.eq(String.to_lower(text), "xor"), XorWord{text}, Bool.pick(Token, String.eq(String.to_lower(text), "not"), NotWord{text}, Identifier{text}))))

def space_flush(mode: Mode, tokens: List<&2, Token>) -> List<&2, Token>:
  match mode:
    case Word{reversed}:
      spaced_word(String.reverse(reversed)) <> tokens
    case mode:
      flush(mode, tokens)

def step(kind: CharacterClass, mode: Mode, tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match kind mode:
    case Digit{n, c} AliasPending{is_and}:
      (Idle{}, Invalid{c} <> tokens)
    case Digit{n, c} Pending{first}:
      (Digits{[U32.from_nat(n)]}, symbol(first) <> tokens)
    case Digit{n, c} Quoted{quote, text}:
      (Quoted{quote, SCon{c, text}}, tokens)
    case Digit{n, c} Idle{}:
      (Digits{[U32.from_nat(n)]}, tokens)
    case Digit{n, c} Digits{v}:
      (Digits{U32.from_nat(n) <> v}, tokens)
    case Digit{n, c} Fraction{digits, scale}:
      (Fraction{U32.from_nat(n) <> digits, 1n+scale}, tokens)
    case Digit{n, c} Word{s}:
      (Word{SCon{c, s}}, tokens)
    case Letter{c} Word{s}:
      (Word{SCon{c, s}}, tokens)
    case Letter{c} mode:
      (Word{SCon{c, SNil{}}}, flush(mode, tokens))
    case Space{} mode:
      (Idle{}, space_flush(mode, tokens))
    case Symbol{Chr{46}} Digits{digits}:
      (Fraction{digits, 0n}, tokens)
    case Symbol{Chr{46}} Idle{}:
      (Fraction{Nil{}, 0n}, tokens)
    case Symbol{c} mode:
      (Idle{}, symbol(c) <> flush(mode, tokens))

def quote_step(same: Bool, c: Char, quote: Char, reversed: String, tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match same:
    case True{}:
      (Idle{}, StringLiteral{String.reverse(reversed)} <> tokens)
    case False{}:
      (Quoted{quote, SCon{c, reversed}}, tokens)

def normal_step(mode: Mode, c: Char, tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match c:
    case Chr{38}:
      (Pending{Chr{38}}, flush(mode, tokens))
    case Chr{124}:
      (Pending{Chr{124}}, flush(mode, tokens))
    case Chr{34}:
      (Quoted{Chr{34}, SNil{}}, flush(mode, tokens))
    case Chr{39}:
      (Quoted{Chr{39}, SNil{}}, flush(mode, tokens))
    case Chr{61}:
      (Pending{Chr{61}}, flush(mode, tokens))
    case Chr{60}:
      (Pending{Chr{60}}, flush(mode, tokens))
    case Chr{62}:
      (Pending{Chr{62}}, flush(mode, tokens))
    case Chr{33}:
      (Pending{Chr{33}}, flush(mode, tokens))
    case c:
      step(classify(c), mode, tokens)

def pending_step(first: Char, c: Char, tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match first c:
    case Chr{38} Chr{38}:
      (AliasPending{True{}}, tokens)
    case Chr{124} Chr{124}:
      (AliasPending{False{}}, tokens)
    case Chr{60} Chr{61}:
      (Idle{}, LessEqualToken{} <> tokens)
    case Chr{62} Chr{61}:
      (Idle{}, GreaterEqualToken{} <> tokens)
    case Chr{33} Chr{61}:
      (Idle{}, NotEqualToken{} <> tokens)
    case Chr{60} Chr{62}:
      (Idle{}, NotEqualToken{} <> tokens)
    case Chr{61} Chr{61}:
      (Idle{}, EqualToken{} <> tokens)
    case first c:
      normal_step(Idle{}, c, symbol(first) <> tokens)

def alias_step(space: Bool, is_and: Bool, c: Char, tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match space:
    case True{}:
      (Idle{}, Bool.pick(Token, is_and, AndWord{"&&"}, OrWord{"||"}) <> tokens)
    case False{}:
      (Idle{}, Invalid{c} <> tokens)

def scan_step(mode: Mode, c: Char, tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match mode c:
    case AliasPending{is_and} +c:
      alias_step(Char.is_space(c), is_and, c, tokens)
    case Quoted{+quote, text} +c:
      quote_step(Char.is_eq(c, quote), c, quote, text, tokens)
    case Pending{first} c:
      pending_step(first, c, tokens)
    case mode c:
      normal_step(mode, c, tokens)

def continue_scan(result: Mode & List<&2, Token>, next: Mode -> List<&2, Token> -> List<&2, Token>) -> List<&2, Token>:
  (mode, tokens) = result
  next(mode, tokens)

def scan(s: String, mode: Mode, tokens: List<&2, Token>) -> List<&2, Token>:
  match s:
    case SNil{}:
      List.reverse(&2, Token, flush(mode, tokens))
    case SCon{c, rest}:
      continue_scan(scan_step(mode, c, tokens), m => ts => scan(rest, m, ts))

def tokenize(s: String) -> List<&2, Token>:
  scan(s, Idle{}, Nil{})
