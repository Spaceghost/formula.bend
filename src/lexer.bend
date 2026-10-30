import Base

type Token is Data:
  Integer{value: Nat}
  Identifier{name: String}
  Plus{}
  Times{}
  LParen{}
  RParen{}
  Invalid{character: Char}

type Mode is Data:
  Idle{}
  Digits{value: Nat}
  Word{reversed: String}

type CharacterClass is Data:
  Digit{value: Nat, character: Char}
  Letter{character: Char}
  Space{}
  Symbol{character: Char}

def classify(+c: Char) -> CharacterClass:
  Bool.pick(CharacterClass, Char.is_digit(c), Digit{U32.to_nat(U32.sub(Char.to_u32(c), 48)), c}, Bool.pick(CharacterClass, Bool.or(Char.is_alpha(c), Char.is_eq(c, '_')), Letter{c}, Bool.pick(CharacterClass, Char.is_space(c), Space{}, Symbol{c})))

def flush(mode: Mode, tokens: List<&2, Token>) -> List<&2, Token>:
  match mode:
    case Idle{}:
      tokens
    case Digits{n}:
      Integer{n} <> tokens
    case Word{s}:
      Identifier{String.reverse(s)} <> tokens

def symbol(c: Char) -> Token:
  match c:
    case Chr{43}:
      Plus{}
    case Chr{42}:
      Times{}
    case Chr{40}:
      LParen{}
    case Chr{41}:
      RParen{}
    case c:
      Invalid{c}

def step(kind: CharacterClass, mode: Mode, tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match kind mode:
    case Digit{n, c} Idle{}:
      (Digits{n}, tokens)
    case Digit{n, c} Digits{v}:
      (Digits{Nat.add(Nat.mul(v, 10n), n)}, tokens)
    case Digit{n, c} Word{s}:
      (Word{SCon{c, s}}, tokens)
    case Letter{c} Word{s}:
      (Word{SCon{c, s}}, tokens)
    case Letter{c} mode:
      (Word{SCon{c, SNil{}}}, flush(mode, tokens))
    case Space{} mode:
      (Idle{}, flush(mode, tokens))
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
