import Base
import ./decimal.bend as Decimal
import ./binary64.bend as Binary
import ./binary64_decimal.bend as Conversion
import ./binary64_bigdecimal.bend as BigDecimal
import ./binary64_format.bend as Format
import ./bits.bend as Bits

type ExactKind is Data:
  IntegerKind{}
  DecimalKind{}

type Special is Data:
  Infinity{negative: Bool}
  NotANumber{}

type Number is Data:
  Exact{kind: ExactKind, negative: Bool, magnitude: Decimal.Decimal}
  Floating{value: Binary.Float}
  Exceptional{value: Special}

type Operation is Data:
  Sum{}
  Product{}

type CalculationResult is Data:
  Calculated{value: Number}
  Rejected{message: String}
  NativeRejected{class_name: String, message: String}

def projected(value: Conversion.Exact) -> Number:
  match value:
    case Conversion.Finite{negative, magnitude}:
      Exact{DecimalKind{}, negative, magnitude}
    case Conversion.Infinite{negative}:
      Exceptional{Infinity{negative}}
    case Conversion.NotANumber{}:
      Exceptional{NotANumber{}}

def decimal_profile(profile: BigDecimal.Profile, value: Number) -> Number:
  match value:
    case Floating{value}:
      projected(BigDecimal.from_float(profile, value))
    case value:
      value

def has_decimal(value: Number) -> Bool:
  match value:
    case Exact{DecimalKind{}, negative, magnitude}:
      True{}
    case Exceptional{value}:
      True{}
    case value:
      False{}

def binary(value: Number) -> Binary.Float:
  match value:
    case Floating{value}:
      value
    case Exact{IntegerKind{}, negative, Decimal.Exact{digits, scale}}:
      Binary.quantize(Bits.from_decimal(digits), 0n, negative, False{})
    case Exact{DecimalKind{}, negative, magnitude}:
      Conversion.from_decimal(negative, magnitude)
    case Exceptional{Infinity{negative}}:
      Binary.infinity(negative)
    case Exceptional{NotANumber{}}:
      Binary.nan()

def finite_kind(kind: Binary.Classification) -> Bool:
  match kind:
    case Binary.Finite{}:
      True{}
    case kind:
      False{}

def is_finite(value: Number) -> Bool:
  match value:
    case Exact{kind, negative, magnitude}:
      True{}
    case Floating{value}:
      finite_kind(Binary.kind(value))
    case Exceptional{value}:
      False{}

def is_zero(value: Number) -> Bool:
  match value:
    case Exact{kind, negative, magnitude}:
      Decimal.is_zero(magnitude)
    case Floating{value}:
      Binary.is_zero(value)
    case Exceptional{value}:
      False{}

def special_text(value: Special) -> String:
  match value:
    case Infinity{negative}:
      Bool.pick(String, negative, "-Infinity", "Infinity")
    case NotANumber{}:
      "NaN"

def render(value: Number) -> String:
  match value:
    case Exact{IntegerKind{}, negative, magnitude}:
      Bool.pick(String, negative, "-", "") ++ Decimal.show(magnitude)
    case Exact{DecimalKind{}, negative, magnitude}:
      Decimal.ruby_show(magnitude, negative)
    case Floating{value}:
      Format.show(value)
    case Exceptional{value}:
      special_text(value)

def exact_result(kind: ExactKind, negative: Bool, +magnitude: Decimal.Decimal) -> Number:
  match kind:
    case IntegerKind{}:
      Exact{IntegerKind{}, Bool.and(negative, Bool.not(Decimal.is_zero(magnitude))), magnitude}
    case DecimalKind{}:
      Exact{DecimalKind{}, negative, magnitude}

def combined_kind(a: ExactKind, b: ExactKind) -> ExactKind:
  match a b:
    case IntegerKind{} IntegerKind{}:
      IntegerKind{}
    case a b:
      DecimalKind{}

def difference(order: Cmp, kind: ExactKind, sa: Bool, +a: Decimal.Decimal, sb: Bool, +b: Decimal.Decimal) -> Number:
  match order:
    case LT{}:
      exact_result(kind, sb, Decimal.subtract(b, a))
    case EQ{}:
      exact_result(kind, False{}, Decimal.subtract(a, b))
    case GT{}:
      exact_result(kind, sa, Decimal.subtract(a, b))

def exact_sum(same: Bool, kind: ExactKind, sa: Bool, +a: Decimal.Decimal, sb: Bool, +b: Decimal.Decimal) -> Number:
  match same:
    case True{}:
      exact_result(kind, sa, Decimal.add(a, b))
    case False{}:
      difference(Decimal.compare(a, b), kind, sa, a, sb, b)

def exact_operation(operation: Operation, kind: ExactKind, +sa: Bool, a: Decimal.Decimal, +sb: Bool, b: Decimal.Decimal) -> Number:
  match operation:
    case Sum{}:
      exact_sum(Cmp.is_eq(Bool.cmp(sa, sb)), kind, sa, a, sb, b)
    case Product{}:
      exact_result(kind, Bool.xor(sa, sb), Decimal.multiply(a, b))

def binary_operation(operation: Operation, a: Binary.Float, b: Binary.Float) -> Binary.Float:
  match operation:
    case Sum{}:
      Binary.add(a, b)
    case Product{}:
      Binary.multiply(a, b)

# Exceptional decimal arithmetic only needs the finite operand's zero/sign,
# never a lossy conversion of an arbitrarily large decimal to binary64.
def finite_proxy(zero: Bool, negative: Bool) -> Binary.Float:
  match zero:
    case True{}:
      Binary.zero(negative)
    case False{}:
      Binary.Binary64{negative, 1023, 0, 0}

def proxy(value: Number) -> Binary.Float:
  match value:
    case Exact{kind, negative, magnitude}:
      finite_proxy(Decimal.is_zero(magnitude), negative)
    case value:
      binary(value)

def decimal_operation(operation: Operation, a: Number, b: Number) -> Number:
  match a b:
    case Exact{ka, sa, a} Exact{kb, sb, b}:
      exact_operation(operation, combined_kind(ka, kb), sa, a, sb, b)
    case a b:
      projected(Conversion.to_exact(binary_operation(operation, proxy(a), proxy(b))))

def ordinary_operation(operation: Operation, a: Number, b: Number) -> Number:
  match a b:
    case Exact{ka, sa, a} Exact{kb, sb, b}:
      exact_operation(operation, combined_kind(ka, kb), sa, a, sb, b)
    case a b:
      Floating{binary_operation(operation, binary(a), binary(b))}

def promoted_operation(decimal: Bool, operation: Operation, a: Number, b: Number) -> Number:
  match decimal:
    case True{}:
      decimal_operation(operation, decimal_profile(BigDecimal.Implicit{}, a), decimal_profile(BigDecimal.Implicit{}, b))
    case False{}:
      ordinary_operation(operation, a, b)

def operator_name(operation: Operation) -> String:
  match operation:
    case Sum{}:
      "+"
    case Product{}:
      "*"

def guarded(invalid: Bool, value: Number, operation: Operation, a: Number, b: Number) -> CalculationResult:
  match invalid:
    case True{}:
      Rejected{"Result of " ++ render(a) ++ " " ++ operator_name(operation) ++ " " ++ render(b) ++ " is not a finite number"}
    case False{}:
      Calculated{value}

def operate_unchecked(operation: Operation, +a: Number, +b: Number) -> Number:
  promoted_operation(Bool.or(has_decimal(a), has_decimal(b)), operation, a, b)

def operate(+operation: Operation, +a: Number, +b: Number) -> CalculationResult:
  +result = operate_unchecked(operation, a, b)
  guarded(Bool.and(Bool.and(is_finite(a), is_finite(b)), Bool.not(is_finite(result))), result, operation, a, b)

def reverse(order: Cmp) -> Cmp:
  match order:
    case LT{}:
      GT{}
    case EQ{}:
      EQ{}
    case GT{}:
      LT{}

def signed_compare(same: Bool, negative: Bool, a: Decimal.Decimal, b: Decimal.Decimal) -> Cmp:
  match same negative:
    case True{} False{}:
      Decimal.compare(a, b)
    case True{} True{}:
      reverse(Decimal.compare(a, b))
    case False{} True{}:
      LT{}
    case False{} False{}:
      GT{}

def compare_signs(+sa: Bool, a: Decimal.Decimal, +sb: Bool, b: Decimal.Decimal) -> Cmp:
  signed_compare(Cmp.is_eq(Bool.cmp(sa, sb)), sa, a, b)

def exact_projection(value: Number) -> Number:
  match value:
    case Floating{value}:
      projected(Conversion.to_exact(value))
    case value:
      value

def compare_projected(a: Number, b: Number) -> Maybe<&2, Cmp>:
  match a b:
    case Exceptional{NotANumber{}} b:
      None{}
    case a Exceptional{NotANumber{}}:
      None{}
    case Exceptional{Infinity{sa}} Exceptional{Infinity{sb}}:
      Some{Bool.cmp(sb, sa)}
    case Exceptional{Infinity{negative}} b:
      Some{Bool.pick(Cmp, negative, LT{}, GT{})}
    case a Exceptional{Infinity{negative}}:
      Some{Bool.pick(Cmp, negative, GT{}, LT{})}
    case Exact{ka, sa, +a} Exact{kb, sb, +b}:
      Some{compare_signs(Bool.and(sa, Bool.not(Decimal.is_zero(a))), a, Bool.and(sb, Bool.not(Decimal.is_zero(b))), b)}
    case a b:
      None{}

def compare_profiles(decimal: Bool, a: Number, b: Number) -> Maybe<&2, Cmp>:
  match decimal:
    case True{}:
      compare_projected(decimal_profile(BigDecimal.Implicit{}, a), decimal_profile(BigDecimal.Implicit{}, b))
    case False{}:
      compare_projected(exact_projection(a), exact_projection(b))

def compare(a: Number, b: Number) -> Maybe<&2, Cmp>:
  match a b:
    case Floating{a} Floating{b}:
      Binary.compare(a, b)
    case +a +b:
      compare_profiles(Bool.or(has_decimal(a), has_decimal(b)), a, b)
