import Base
import ./decimal.bend as Decimal

type Token is Data:
  Integer{value: Nat}
  DecimalLiteral{value: Decimal.Decimal}
  Identifier{name: String}
  Plus{}
  Minus{}
  Times{}
  Slash{}
  LParen{}
  RParen{}
  Comma{}
  Invalid{character: Char}

type Mode is Data:
  Idle{}
  Digits{reversed: List<&2, U32>}
  Fraction{reversed: List<&2, U32>, scale: Nat}
  Word{reversed: String}

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

def flush(mode: Mode, tokens: List<&2, Token>) -> List<&2, Token>:
  match mode:
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

def symbol(c: Char) -> Token:
  match c:
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

def step(kind: CharacterClass, mode: Mode, tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match kind mode:
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
      (Idle{}, flush(mode, tokens))
    case Symbol{Chr{46}} Digits{digits}:
      (Fraction{digits, 0n}, tokens)
    case Symbol{Chr{46}} Idle{}:
      (Fraction{Nil{}, 0n}, tokens)
    case Symbol{c} mode:
      (Idle{}, symbol(c) <> flush(mode, tokens))

def continue_scan(result: Mode & List<&2, Token>, next: Mode -> List<&2, Token> -> List<&2, Token>) -> List<&2, Token>:
  (mode, tokens) = result
  next(mode, tokens)

def scan(s: String, mode: Mode, tokens: List<&2, Token>) -> List<&2, Token>:
  match s:
    case SNil{}:
      List.reverse(&2, Token, flush(mode, tokens))
    case SCon{c, rest}:
      continue_scan(step(classify(c), mode, tokens), m => ts => scan(rest, m, ts))

def tokenize(s: String) -> List<&2, Token>:
  scan(s, Idle{}, Nil{})
