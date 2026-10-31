import Base
import ./bits.bend as Bits

# Portable binary64 arithmetic. Every intermediate is an exact bit list; the
# only rounding is round-to-nearest, ties-to-even at the final binary64 boundary.
# No host Float/F32 arithmetic, flush-to-zero, or fused operations are used.
type Float is Data:
  Binary64{negative: Bool, exponent: U32, fraction_high: U32, low: U32}

type Classification is Data:
  Finite{}
  Infinite{}
  NotANumber{}

def from_words(+high: U32, low: U32) -> Float:
  Binary64{U32.is_ne(U32.and(high, 2147483648), 0), U32.and(U32.shrn(high, 20n), 2047), U32.and(high, 1048575), low}

def words(value: Float) -> U32 & U32:
  match value:
    case Binary64{negative, exponent, fraction_high, low}:
      (U32.or(Bool.pick(U32, negative, 2147483648, 0), U32.or(U32.shln(exponent, 20n), fraction_high)), low)

def negate(value: Float) -> Float:
  match value:
    case Binary64{negative, exponent, fraction_high, low}:
      Binary64{Bool.not(negative), exponent, fraction_high, low}

def sign(value: Float) -> Bool:
  match value:
    case Binary64{negative, exponent, fraction_high, low}:
      negative

def zero(negative: Bool) -> Float:
  Binary64{negative, 0, 0, 0}

def infinity(negative: Bool) -> Float:
  Binary64{negative, 2047, 0, 0}

# Arithmetic NaNs are canonical; input words retain their payload until used.
# Ruby does not promise a portable sign or payload for an arithmetic NaN.
def nan() -> Float:
  Binary64{False{}, 2047, 524288, 0}

def special(exponent: U32, +high: U32, +low: U32) -> Classification:
  Bool.pick(Classification, U32.is_eq(exponent, 2047), Bool.pick(Classification, Bool.and(U32.is_eq(high, 0), U32.is_eq(low, 0)), Infinite{}, NotANumber{}), Finite{})

def kind(value: Float) -> Classification:
  match value:
    case Binary64{negative, exponent, high, low}:
      special(exponent, high, low)

def is_zero(value: Float) -> Bool:
  match value:
    case Binary64{negative, exponent, high, low}:
      Bool.and(U32.is_eq(exponent, 0), Bool.and(U32.is_eq(high, 0), U32.is_eq(low, 0)))

def word_bits(count: Nat, +word: U32) -> List<&2, Bool>:
  match count:
    case 0n:
      Nil{}
    case 1n+rest:
      U32.is_ne(U32.and(word, 1), 0) <> word_bits(rest, U32.shr(word))

def significand(value: Float) -> List<&2, Bool>:
  match value:
    case Binary64{negative, +exponent, high, low}:
      Bits.normalize(List.append(&2, Bool, word_bits(32n, low), List.append(&2, Bool, word_bits(20n, high), Bool.pick(List<&2, Bool>, U32.is_eq(exponent, 0), Nil{}, [True{}]))))

# All finite inputs are significand * 2^shift * 2^-1074.
def shift(value: Float) -> Nat:
  match value:
    case Binary64{negative, exponent, high, low}:
      Nat.sub(U32.to_nat(exponent), 1n)

def pad(count: Nat, bits: List<&2, Bool>) -> List<&2, Bool>:
  match count:
    case 0n:
      bits
    case 1n+rest:
      False{} <> pad(rest, bits)

def word_value(bits: List<&2, Bool>) -> U32:
  match bits:
    case Nil{}:
      0
    case bit <> rest:
      U32.or(Bool.to_u32(bit), U32.shl(word_value(rest)))

def encode(negative: Bool, exponent: Nat, +fraction: List<&2, Bool>) -> Float:
  Binary64{negative, U32.from_nat(exponent), U32.and(word_value(Bits.drop_low(fraction, 32n)), 1048575), word_value(fraction)}

type Removed is Data:
  Cut{kept: List<&2, Bool>, guard: Bool, sticky: Bool}

def cut(count: Nat, bits: List<&2, Bool>, +last: Bool, sticky: Bool) -> Removed:
  match count bits:
    case 0n bits:
      Cut{bits, last, sticky}
    case 1n+rest Nil{}:
      cut(rest, Nil{}, False{}, Bool.or(last, sticky))
    case 1n+rest bit <> tail:
      cut(rest, tail, bit, Bool.or(last, sticky))

def odd(bits: List<&2, Bool>) -> Bool:
  match bits:
    case Nil{}:
      False{}
    case bit <> rest:
      bit

def round_cut(parts: Removed) -> List<&2, Bool>:
  match parts:
    case Cut{+kept, guard, sticky}:
      Bool.pick(List<&2, Bool>, Bool.and(guard, Bool.or(sticky, odd(kept))), Bits.add(kept, [True{}]), kept)

def pack_normal(overflow: Bool, negative: Bool, exponent: Nat, +bits: List<&2, Bool>, +length: Nat) -> Float:
  match overflow:
    case True{}:
      infinity(negative)
    case False{}:
      encode(negative, exponent, pad(Nat.sub(53n, length), Bits.drop_low(bits, Nat.sub(length, 53n))))

def pack_magnitude(normal: Bool, negative: Bool, +bits: List<&2, Bool>, +length: Nat, +removed: Nat, +scale: Nat) -> Float:
  match normal:
    case True{}:
      pack_normal(Nat.is_ge(Nat.sub(Nat.add(Nat.add(length, removed), 1022n), scale), 2047n), negative, Nat.sub(Nat.add(Nat.add(length, removed), 1022n), scale), bits, length)
    case False{}:
      encode(negative, 0n, pad(Nat.sub(Nat.add(1074n, removed), scale), bits))

def pack_rounded(bits: List<&2, Bool>, negative: Bool, +removed: Nat, +scale: Nat) -> Float:
  match bits:
    case Nil{}:
      zero(negative)
    case +head <> +rest:
      +length = Nat.add(1n, List.length(&2, Bool, rest))
      pack_magnitude(Nat.is_gt(Nat.add(Nat.add(length, removed), 1022n), scale), negative, head <> rest, length, removed, scale)

def quantize_shift(+removed: Nat, bits: List<&2, Bool>, scale: Nat, negative: Bool, sticky: Bool) -> Float:
  pack_rounded(round_cut(cut(removed, bits, False{}, sticky)), negative, removed, scale)

def rounding_shift(+length: Nat, +scale: Nat) -> Nat:
  +normal = Nat.sub(length, 53n)
  +subnormal = Nat.sub(scale, 1074n)
  Bool.pick(Nat, Nat.is_ge(normal, subnormal), normal, subnormal)

def quantize_normalized(+bits: List<&2, Bool>, +scale: Nat, negative: Bool, sticky: Bool) -> Float:
  quantize_shift(rounding_shift(List.length(&2, Bool, bits), scale), bits, scale, negative, sticky)

def quantize(bits: List<&2, Bool>, scale: Nat, negative: Bool, sticky: Bool) -> Float:
  quantize_normalized(Bits.normalize(bits), scale, negative, sticky)

def round_trip_kind(classification: Classification, +value: Float) -> Float:
  match classification:
    case Finite{}:
      quantize(pad(shift(value), significand(value)), 1074n, sign(value), False{})
    case classification:
      value

def round_trip(+value: Float) -> Float:
  round_trip_kind(kind(value), value)

def compare_high(a: List<&2, Bool>, b: List<&2, Bool>) -> Cmp:
  match a b:
    case Nil{} Nil{}:
      EQ{}
    case Nil{} b:
      LT{}
    case a Nil{}:
      GT{}
    case False{} <> a True{} <> b:
      LT{}
    case True{} <> a False{} <> b:
      GT{}
    case x <> a y <> b:
      compare_high(a, b)

def compare_length(order: Cmp, a: List<&2, Bool>, b: List<&2, Bool>) -> Cmp:
  match order:
    case EQ{}:
      compare_high(List.reverse(&2, Bool, a), List.reverse(&2, Bool, b))
    case order:
      order

def unsigned_compare(+a: List<&2, Bool>, +b: List<&2, Bool>) -> Cmp:
  compare_length(Nat.cmp(List.length(&2, Bool, a), List.length(&2, Bool, b)), a, b)

def subtract_walk(a: List<&2, Bool>, b: List<&2, Bool>, +borrow: Bool, reversed: List<&2, Bool>) -> List<&2, Bool>:
  match a b:
    case Nil{} b:
      Bits.normalize(List.reverse(&2, Bool, reversed))
    case +x <> xs Nil{}:
      subtract_walk(xs, Nil{}, Bool.and(Bool.not(x), borrow), Bool.xor(x, borrow) <> reversed)
    case +x <> xs +y <> ys:
      subtract_walk(xs, ys, Bool.or(Bool.and(Bool.not(x), Bool.or(y, borrow)), Bool.and(y, borrow)), Bool.xor(x, Bool.xor(y, borrow)) <> reversed)

def unsigned_subtract(a: List<&2, Bool>, b: List<&2, Bool>) -> List<&2, Bool>:
  subtract_walk(a, b, False{}, Nil{})

def unsigned_multiply(a: List<&2, Bool>, +b: List<&2, Bool>) -> List<&2, Bool>:
  match a:
    case Nil{}:
      Nil{}
    case bit <> rest:
      row tail = Bool.pick(List<&2, Bool>, bit, b, Nil{}) unsigned_multiply(rest, b)
      Bits.add(row, False{} <> tail)

def signed_difference(order: Cmp, sa: Bool, +a: List<&2, Bool>, sb: Bool, +b: List<&2, Bool>) -> Float:
  match order:
    case EQ{}:
      zero(False{})
    case LT{}:
      quantize(unsigned_subtract(b, a), 1074n, sb, False{})
    case GT{}:
      quantize(unsigned_subtract(a, b), 1074n, sa, False{})

def signed_sum(same: Bool, +sa: Bool, +a: List<&2, Bool>, sb: Bool, +b: List<&2, Bool>) -> Float:
  match same:
    case True{}:
      quantize(Bits.add(a, b), 1074n, sa, False{})
    case False{}:
      signed_difference(unsigned_compare(a, b), sa, a, sb, b)

def add_kind(ka: Classification, kb: Classification, +a: Float, +b: Float) -> Float:
  match ka kb:
    case NotANumber{} kb:
      nan()
    case ka NotANumber{}:
      nan()
    case Infinite{} Infinite{}:
      Bool.pick(Float, Cmp.is_eq(Bool.cmp(sign(a), sign(b))), a, nan())
    case Infinite{} kb:
      a
    case ka Infinite{}:
      b
    case Finite{} Finite{}:
      signed_sum(Cmp.is_eq(Bool.cmp(sign(a), sign(b))), sign(a), pad(shift(a), significand(a)), sign(b), pad(shift(b), significand(b)))

def add(+a: Float, +b: Float) -> Float:
  add_kind(kind(a), kind(b), a, b)

def subtract(a: Float, b: Float) -> Float:
  add(a, negate(b))

def infinite_product(zero_operand: Bool, negative: Bool) -> Float:
  Bool.pick(Float, zero_operand, nan(), infinity(negative))

def multiply_kind(ka: Classification, kb: Classification, +a: Float, +b: Float) -> Float:
  match ka kb:
    case NotANumber{} kb:
      nan()
    case ka NotANumber{}:
      nan()
    case Infinite{} kb:
      infinite_product(is_zero(b), Bool.xor(sign(a), sign(b)))
    case ka Infinite{}:
      infinite_product(is_zero(a), Bool.xor(sign(a), sign(b)))
    case Finite{} Finite{}:
      quantize(pad(Nat.add(shift(a), shift(b)), unsigned_multiply(significand(a), significand(b))), 2148n, Bool.xor(sign(a), sign(b)), False{})

def multiply(+a: Float, +b: Float) -> Float:
  multiply_kind(kind(a), kind(b), a, b)

type DivisionStep is Data:
  Step{bit: Bool, remainder: List<&2, Bool>}

def division_step(less: Bool, +remainder: List<&2, Bool>, divisor: List<&2, Bool>) -> DivisionStep:
  match less:
    case True{}:
      Step{False{}, remainder}
    case False{}:
      Step{True{}, unsigned_subtract(remainder, divisor)}

def continue_step(step: DivisionStep, next: Bool -> List<&2, Bool> -> (List<&2, Bool> & List<&2, Bool>)) -> List<&2, Bool> & List<&2, Bool>:
  match step:
    case Step{bit, remainder}:
      next(bit, remainder)

def divide_walk(input: List<&2, Bool>, +divisor: List<&2, Bool>, remainder: List<&2, Bool>, quotient: List<&2, Bool>) -> List<&2, Bool> & List<&2, Bool>:
  match input:
    case Nil{}:
      (Bits.normalize(quotient), remainder)
    case bit <> rest:
      +brought = Bits.normalize(bit <> remainder)
      continue_step(division_step(Cmp.is_lt(unsigned_compare(brought, divisor)), brought, divisor), q => r => divide_walk(rest, divisor, r, q <> quotient))

def quotient_result(parts: List<&2, Bool> & List<&2, Bool>, negative: Bool) -> Float:
  (quotient, remainder) = parts
  quantize(quotient, 1075n, negative, Bool.not(List.is_empty(&2, Bool, remainder)))

def finite_division(za: Bool, zb: Bool, +a: Float, +b: Float) -> Float:
  match za zb:
    case True{} True{}:
      nan()
    case False{} True{}:
      infinity(Bool.xor(sign(a), sign(b)))
    case True{} False{}:
      zero(Bool.xor(sign(a), sign(b)))
    case False{} False{}:
      quotient_result(divide_walk(List.reverse(&2, Bool, pad(Nat.add(1075n, Nat.sub(shift(a), shift(b))), significand(a))), pad(Nat.sub(shift(b), shift(a)), significand(b)), Nil{}, Nil{}), Bool.xor(sign(a), sign(b)))

def divide_kind(ka: Classification, kb: Classification, +a: Float, +b: Float) -> Float:
  match ka kb:
    case NotANumber{} kb:
      nan()
    case ka NotANumber{}:
      nan()
    case Infinite{} Infinite{}:
      nan()
    case Infinite{} kb:
      infinity(Bool.xor(sign(a), sign(b)))
    case ka Infinite{}:
      zero(Bool.xor(sign(a), sign(b)))
    case Finite{} Finite{}:
      finite_division(is_zero(a), is_zero(b), a, b)

def divide(+a: Float, +b: Float) -> Float:
  divide_kind(kind(a), kind(b), a, b)

def next_order(order: Cmp, rest: Cmp) -> Cmp:
  match order:
    case EQ{}:
      rest
    case order:
      order

def magnitude_order(a: Float, b: Float) -> Cmp:
  match a b:
    case Binary64{sa, ea, ha, la} Binary64{sb, eb, hb, lb}:
      next_order(U32.cmp(ea, eb), next_order(U32.cmp(ha, hb), U32.cmp(la, lb)))

def reverse_order(order: Cmp) -> Cmp:
  match order:
    case LT{}:
      GT{}
    case EQ{}:
      EQ{}
    case GT{}:
      LT{}

def signed_order(negative: Bool, +order: Cmp) -> Cmp:
  Bool.pick(Cmp, negative, reverse_order(order), order)

def compare_signs(same: Bool, +negative: Bool, a: Float, b: Float) -> Cmp:
  match same:
    case False{}:
      Bool.pick(Cmp, negative, LT{}, GT{})
    case True{}:
      signed_order(negative, magnitude_order(a, b))

def compare_zeros(both_zero: Bool, +a: Float, +b: Float) -> Cmp:
  match both_zero:
    case True{}:
      EQ{}
    case False{}:
      compare_signs(Cmp.is_eq(Bool.cmp(sign(a), sign(b))), sign(a), a, b)

def compare_right(kb: Classification, +a: Float, +b: Float) -> Maybe<&2, Cmp>:
  match kb:
    case NotANumber{}:
      None{}
    case kb:
      Some{compare_zeros(Bool.and(is_zero(a), is_zero(b)), a, b)}

def compare_kind(ka: Classification, kb: Classification, a: Float, b: Float) -> Maybe<&2, Cmp>:
  match ka:
    case NotANumber{}:
      None{}
    case ka:
      compare_right(kb, a, b)

def compare(+a: Float, +b: Float) -> Maybe<&2, Cmp>:
  compare_kind(kind(a), kind(b), a, b)

def render_words(parts: U32 & U32) -> String:
  (high, low) = parts
  U32.show(high) ++ ":" ++ U32.show(low)

def snapshot_kind(classification: Classification, value: Float) -> String:
  match classification:
    case NotANumber{}:
      "nan"
    case classification:
      render_words(words(value))

def snapshot(+value: Float) -> String:
  snapshot_kind(kind(value), value)
