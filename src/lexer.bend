import Base
import ./decimal.bend as Decimal
import ./unicode.bend as Unicode

type Token is Data:
  Integer{value: Nat}
  BigIntegerLiteral{value: Decimal.Decimal}
  DecimalLiteral{value: Decimal.Decimal}
  Identifier{name: String}
  QuotedIdentifier{name: String}
  InvalidQuotedIdentifier{}
  MemberName{name: String}
  InvalidMemberSpacing{}
  StringLiteral{value: String}
  Plus{}
  Minus{}
  Times{}
  Slash{}
  ModuloToken{}
  BitOrToken{}
  BitAndToken{}
  ShiftLeftToken{}
  ShiftRightToken{}
  LParen{}
  RParen{}
  LBrace{}
  RBrace{}
  LBracket{}
  RBracket{}
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
  InvalidLogicalAlias{}
  Invalid{character: Char}
  InvalidNumeric{}
  CaseWord{}
  WhenWord{}
  ThenWord{}
  ElseWord{}
  EndWord{}

type Mode is Data:
  Idle{}
  AfterClose{}
  AfterCloseSpace{}
  MemberStart{}
  MemberWord{reversed: String}
  Digits{reversed: List<&2, U32>}
  Fraction{reversed: List<&2, U32>, scale: Nat}
  Word{reversed: String}
  Quoted{quote: Char, reversed: String}
  QuotedName{reversed: String}
  Pending{symbol: Char}
  AliasPending{is_and: Bool}
  Scientific{digits: List<&2, U32>, scale: Nat, negative: Bool, exponent: List<&2, U32>, sign_allowed: Bool, explicit_sign: Bool, prefix: String}
  Hexadecimal{digits: List<&2, U32>, seen: Bool, reversed: String}

type CharacterClass is Data:
  Digit{value: Nat, character: Char}
  Letter{character: Char}
  Space{}
  Symbol{character: Char}

def classify(+c: Char) -> CharacterClass:
  Bool.pick(CharacterClass, Char.is_digit(c), Digit{U32.to_nat(U32.sub(Char.to_u32(c), 48)), c}, Bool.pick(CharacterClass, Unicode.is_word(c), Letter{c}, Bool.pick(CharacterClass, Char.is_space(c), Space{}, Symbol{c})))

def integer_token(+digits: List<&2, U32>, small: Bool) -> Token:
  match small:
    case True{}:
      Integer{Decimal.coefficient(digits)}
    case False{}:
      BigIntegerLiteral{Decimal.Exact{digits, 0n}}

def symbol(c: Char) -> Token:
  match c:
    case Chr{123}:
      LBrace{}
    case Chr{125}:
      RBrace{}
    case Chr{91}:
      LBracket{}
    case Chr{93}:
      RBracket{}
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
    case Chr{37}:
      ModuloToken{}
    case Chr{124}:
      BitOrToken{}
    case Chr{38}:
      BitAndToken{}
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

def scientific_scaled(digits: List<&2, U32>, +scale: Nat, negative: Bool, +exponent: Nat) -> Token:
  match negative:
    case True{}:
      DecimalLiteral{Decimal.Exact{digits, Nat.add(scale, exponent)}}
    case False{}:
      DecimalLiteral{Decimal.Exact{Decimal.pad(Nat.sub(exponent, scale), digits), Nat.sub(scale, exponent)}}

def scientific_fits(fits: Bool, digits: List<&2, U32>, scale: Nat, negative: Bool, exponent: List<&2, U32>) -> Token:
  match fits:
    case True{}:
      scientific_scaled(digits, scale, negative, Decimal.coefficient(exponent))
    case False{}:
      InvalidNumeric{}

def scientific_token(digits: List<&2, U32>, scale: Nat, negative: Bool, exponent: List<&2, U32>) -> Token:
  match exponent:
    case Nil{}:
      InvalidNumeric{}
    case +head <> +tail:
      scientific_fits(Nat.is_le(List.length(&2, U32, Decimal.normalize_digits(head <> tail)), 14n), digits, scale, negative, head <> tail)

def fraction_reversed(digits: List<&2, U32>, scale: Nat) -> String:
  match digits scale:
    case digits 0n:
      SCon{Chr{46}, Decimal.digit_text(digits)}
    case head <> rest 1n+p:
      SCon{Chr{U32.add(48, head)}, fraction_reversed(rest, p)}
    case Nil{} 1n+p:
      SCon{Chr{48}, fraction_reversed(Nil{}, p)}

def numeric_word_choose(digit: Bool, yes: Unit -> (Mode & List<&2, Token>), no: Unit -> (Mode & List<&2, Token>)) -> Mode & List<&2, Token>:
  match digit:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def numeric_word_parts(source: String, +prefix_digits: List<&2, U32>, +original: String, +tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match source:
    case SNil{}:
      (Word{original}, tokens)
    case SCon{Chr{46}, rest}:
      (Word{String.reverse(SCon{Chr{46}, rest})}, Bool.pick(List<&2, Token>, List.is_empty(&2, U32, prefix_digits), tokens, integer_token(prefix_digits, Nat.is_le(List.length(&2, U32, prefix_digits), 3n)) <> tokens))
    case SCon{+c, rest}:
      numeric_word_choose(Char.is_digit(c), u => numeric_word_parts(rest, U32.sub(Char.to_u32(c), 48) <> prefix_digits, original, tokens), u => (Word{original}, tokens))

def numeric_word(+reversed: String, tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  numeric_word_parts(String.reverse(reversed), Nil{}, reversed, tokens)

def flush_word_result(result: Mode & List<&2, Token>) -> List<&2, Token>:
  (mode, tokens) = result
  match mode:
    case Word{s}:
      Identifier{String.reverse(s)} <> tokens
    case mode:
      tokens

def scientific_prefix_tokens(explicit_sign: Bool, negative: Bool, prefix: String, tokens: List<&2, Token>) -> List<&2, Token>:
  match explicit_sign:
    case True{}:
      Bool.pick(Token, negative, Minus{}, Plus{}) <> flush_word_result(numeric_word(prefix, tokens))
    case False{}:
      flush_word_result(numeric_word(prefix, tokens))

def flush_scientific(digits: List<&2, U32>, scale: Nat, negative: Bool, exponent: List<&2, U32>, explicit_sign: Bool, prefix: String, tokens: List<&2, Token>) -> List<&2, Token>:
  match exponent:
    case Nil{}:
      scientific_prefix_tokens(explicit_sign, negative, prefix, tokens)
    case head <> tail:
      scientific_token(digits, scale, negative, head <> tail) <> tokens

def reserved_word(+text: String) -> Token:
  Bool.pick(Token, String.eq(String.to_lower(text), "case"), CaseWord{}, Bool.pick(Token, String.eq(String.to_lower(text), "when"), WhenWord{}, Bool.pick(Token, String.eq(String.to_lower(text), "then"), ThenWord{}, Bool.pick(Token, String.eq(String.to_lower(text), "else"), ElseWord{}, Bool.pick(Token, String.eq(String.to_lower(text), "end"), EndWord{}, Identifier{text})))))

def flush(mode: Mode, tokens: List<&2, Token>) -> List<&2, Token>:
  match mode:
    case AfterClose{}:
      tokens
    case AfterCloseSpace{}:
      tokens
    case MemberStart{}:
      InvalidMemberSpacing{} <> tokens
    case MemberWord{s}:
      MemberName{String.reverse(s)} <> tokens
    case Scientific{digits, scale, negative, exponent, sign_allowed, explicit_sign, prefix}:
      flush_scientific(digits, scale, negative, exponent, explicit_sign, prefix, tokens)
    case Hexadecimal{+digits, True{}, raw}:
      integer_token(Decimal.normalize_digits(digits), Nat.is_le(List.length(&2, U32, digits), 3n)) <> tokens
    case Hexadecimal{digits, False{}, raw}:
      Identifier{String.reverse(raw)} <> tokens
    case AliasPending{is_and}:
      InvalidLogicalAlias{} <> tokens
    case Pending{c}:
      symbol(c) <> tokens
    case Quoted{quote, text}:
      Invalid{quote} <> tokens
    case QuotedName{text}:
      InvalidQuotedIdentifier{} <> tokens
    case Idle{}:
      tokens
    case Digits{+n}:
      integer_token(n, Nat.is_le(List.length(&2, U32, n), 3n)) <> tokens
    case Fraction{digits, 0n}:
      InvalidNumeric{} <> tokens
    case Fraction{digits, 1n+p}:
      DecimalLiteral{Decimal.Exact{digits, 1n+p}} <> tokens
    case Word{s}:
      reserved_word(String.reverse(s)) <> tokens

def spaced_word(+text: String) -> Token:
  Bool.pick(Token, String.eq(String.to_lower(text), "and"), AndWord{text}, Bool.pick(Token, String.eq(String.to_lower(text), "or"), OrWord{text}, Bool.pick(Token, String.eq(String.to_lower(text), "xor"), XorWord{text}, Bool.pick(Token, String.eq(String.to_lower(text), "not"), NotWord{text}, reserved_word(text)))))

def space_flush(mode: Mode, tokens: List<&2, Token>) -> List<&2, Token>:
  match mode:
    case Word{reversed}:
      spaced_word(String.reverse(reversed)) <> tokens
    case mode:
      flush(mode, tokens)

def step(kind: CharacterClass, mode: Mode, tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match kind mode:
    case Letter{Chr{101}} Digits{+digits}:
      (Scientific{digits, 0n, False{}, Nil{}, True{}, False{}, SCon{Chr{101}, Decimal.digit_text(digits)}}, tokens)
    case Letter{Chr{69}} Digits{+digits}:
      (Scientific{digits, 0n, False{}, Nil{}, True{}, False{}, SCon{Chr{69}, Decimal.digit_text(digits)}}, tokens)
    case Letter{Chr{101}} Fraction{+digits, 1n+ +p}:
      (Scientific{digits, 1n+p, False{}, Nil{}, True{}, False{}, SCon{Chr{101}, fraction_reversed(digits, 1n+p)}}, tokens)
    case Letter{Chr{69}} Fraction{+digits, 1n+ +p}:
      (Scientific{digits, 1n+p, False{}, Nil{}, True{}, False{}, SCon{Chr{69}, fraction_reversed(digits, 1n+p)}}, tokens)
    case Letter{Chr{120}} Digits{0 <> Nil{}}:
      (Hexadecimal{Nil{}, False{}, "x0"}, tokens)
    case Letter{Chr{88}} Digits{0 <> Nil{}}:
      (Hexadecimal{Nil{}, False{}, "X0"}, tokens)
    case Letter{c} Digits{digits}:
      numeric_word(SCon{c, Decimal.digit_text(digits)}, tokens)
    case Letter{c} Fraction{digits, scale}:
      numeric_word(SCon{c, fraction_reversed(digits, scale)}, tokens)
    case Digit{n, c} AliasPending{is_and}:
      (Idle{}, InvalidLogicalAlias{} <> tokens)
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
    case Symbol{Chr{46}} Word{s}:
      (Word{SCon{Chr{46}, s}}, tokens)
    case Symbol{c} mode:
      (Idle{}, symbol(c) <> flush(mode, tokens))
    case kind mode:
      (Idle{}, Invalid{Chr{0}} <> tokens)

def quote_step(same: Bool, c: Char, quote: Char, reversed: String, tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match same:
    case True{}:
      (Idle{}, StringLiteral{String.reverse(reversed)} <> tokens)
    case False{}:
      (Quoted{quote, SCon{c, reversed}}, tokens)

def normal_step(mode: Mode, c: Char, tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match c:
    case Chr{96}:
      (QuotedName{SNil{}}, flush(mode, tokens))
    case Chr{41}:
      (AfterClose{}, RParen{} <> flush(mode, tokens))
    case Chr{93}:
      (AfterClose{}, RBracket{} <> flush(mode, tokens))
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
    case Chr{60} Chr{60}:
      (Idle{}, ShiftLeftToken{} <> tokens)
    case Chr{62} Chr{62}:
      (Idle{}, ShiftRightToken{} <> tokens)
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
      (Idle{}, InvalidLogicalAlias{} <> tokens)

def scientific_word(explicit_sign: Bool, negative: Bool, exponent: List<&2, U32>, prefix: String, c: Char, tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match explicit_sign:
    case True{}:
      (Word{SCon{c, Decimal.digit_text(exponent)}}, scientific_prefix_tokens(True{}, negative, prefix, tokens))
    case False{}:
      numeric_word(SCon{c, Decimal.digit_text(exponent) ++ prefix}, tokens)

def scientific_step(digits: List<&2, U32>, scale: Nat, negative: Bool, exponent: List<&2, U32>, sign_allowed: Bool, explicit_sign: Bool, prefix: String, kind: CharacterClass, current: Char, tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match sign_allowed kind:
    case sign_allowed Digit{n, c}:
      (Scientific{digits, scale, negative, U32.from_nat(n) <> exponent, False{}, explicit_sign, prefix}, tokens)
    case True{} Symbol{Chr{43}}:
      (Scientific{digits, scale, False{}, exponent, False{}, True{}, prefix}, tokens)
    case True{} Symbol{Chr{45}}:
      (Scientific{digits, scale, True{}, exponent, False{}, True{}, prefix}, tokens)
    case sign_allowed Letter{c}:
      scientific_word(explicit_sign, negative, exponent, prefix, c, tokens)
    case sign_allowed kind:
      normal_step(Idle{}, current, flush_scientific(digits, scale, negative, exponent, explicit_sign, prefix, tokens))

def hexadecimal_digit(+c: Char) -> Maybe<&2, U32>:
  +code = Char.to_u32(Char.to_lower(c))
  Bool.pick(Maybe<&2, U32>, Char.is_digit(c), Some{U32.sub(Char.to_u32(c), 48)}, Bool.pick(Maybe<&2, U32>, Bool.and(U32.is_ge(code, 97), U32.is_le(code, 102)), Some{U32.sub(code, 87)}, None{}))

def hexadecimal_done(kind: CharacterClass, current: Char, digits: List<&2, U32>, seen: Bool, raw: String, tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match kind:
    case Letter{c}:
      (Word{SCon{c, raw}}, tokens)
    case kind:
      normal_step(Idle{}, current, flush(Hexadecimal{digits, seen, raw}, tokens))

def hexadecimal_step(digit: Maybe<&2, U32>, digits: List<&2, U32>, seen: Bool, +c: Char, raw: String, tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match digit:
    case Some{n}:
      (Hexadecimal{Decimal.add_digits(Decimal.multiply_digit(digits, 16, 0), [n], 0), True{}, SCon{c, raw}}, tokens)
    case None{}:
      hexadecimal_done(classify(c), c, digits, seen, raw, tokens)

def scan_step(mode: Mode, c: Char, +tokens: List<&2, Token>) -> Mode & List<&2, Token>:
  match mode c:
    case QuotedName{text} Chr{96}:
      (Idle{}, QuotedIdentifier{String.reverse(text)} <> tokens)
    case QuotedName{text} c:
      (QuotedName{SCon{c, text}}, tokens)
    case AfterClose{} Chr{46}:
      (MemberStart{}, tokens)
    case AfterCloseSpace{} Chr{46}:
      (Idle{}, InvalidMemberSpacing{} <> tokens)
    case AfterClose{} +c:
      Bool.pick(Mode & List<&2, Token>, Char.is_space(c), (AfterCloseSpace{}, tokens), normal_step(Idle{}, c, tokens))
    case AfterCloseSpace{} +c:
      Bool.pick(Mode & List<&2, Token>, Char.is_space(c), (AfterCloseSpace{}, tokens), normal_step(Idle{}, c, tokens))
    case MemberStart{} +c:
      Bool.pick(Mode & List<&2, Token>, Bool.or(Unicode.is_alpha(c), Char.is_eq(c, '_')), (MemberWord{SCon{c, SNil{}}}, tokens), normal_step(Idle{}, c, Bool.pick(Token, Char.is_digit(c), Invalid{Chr{46}}, InvalidMemberSpacing{}) <> tokens))
    case MemberWord{s} Chr{46}:
      (MemberStart{}, MemberName{String.reverse(s)} <> tokens)
    case MemberWord{+s} +c:
      Bool.pick(Mode & List<&2, Token>, Unicode.is_word(c), (MemberWord{SCon{c, s}}, tokens), Bool.pick(Mode & List<&2, Token>, Char.is_space(c), (AfterCloseSpace{}, MemberName{String.reverse(s)} <> tokens), normal_step(Idle{}, c, MemberName{String.reverse(s)} <> tokens)))
    case Scientific{digits, scale, negative, exponent, sign_allowed, explicit_sign, prefix} +c:
      scientific_step(digits, scale, negative, exponent, sign_allowed, explicit_sign, prefix, classify(c), c, tokens)
    case Hexadecimal{digits, seen, raw} +c:
      hexadecimal_step(hexadecimal_digit(c), digits, seen, c, raw, tokens)
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
