import Base
import ../src/binary64.bend as Binary
import ../src/binary64_decimal.bend as Conversion
import ../src/decimal.bend as Decimal
import ../src/binary64_ruby_decimal.bend as RubyConversion

type Operation is Data:
  Add{}
  Subtract{}
  Multiply{}
  Divide{}
  RoundTrip{}
  Compare{}
  Words{}
  ToExact{}
  ExactRoundTrip{}

type Calculation is Data:
  Value{value: Binary.Float}
  Ordering{order: Maybe<&2, Cmp>}
  RawWords{value: Binary.Float}
  ExactValue{value: Conversion.Exact}

type Work is Data:
  Leaf{id: String, operation: Operation, left: Binary.Float, right: Binary.Float}
  Fork{left: Work, right: Work}
  DecimalLeaf{id: String, negative: Bool, magnitude: Decimal.Decimal}
  RubyDecimalLeaf{id: String, negative: Bool, magnitude: Decimal.Decimal}

type Loaded is Data:
  LoadedWork{work: Work}
  Invalid{}

type Results is Data:
  Row{id: String, value: String}
  Joined{left: Results, right: Results}

def operation(text: String) -> Maybe<&2, Operation>:
  match text:
    case "add":
      Some{Add{}}
    case "subtract":
      Some{Subtract{}}
    case "multiply":
      Some{Multiply{}}
    case "divide":
      Some{Divide{}}
    case "roundtrip":
      Some{RoundTrip{}}
    case "compare":
      Some{Compare{}}
    case "words":
      Some{Words{}}
    case "to_exact":
      Some{ToExact{}}
    case "exact_roundtrip":
      Some{ExactRoundTrip{}}
    case text:
      None{}

def word_digits(text: String, +value: Nat) -> Maybe<&2, U32>:
  match text:
    case SNil{}:
      Bool.pick(Maybe<&2, U32>, Nat.is_le(value, 4294967295n), Some{U32.from_nat(value)}, None{})
    case SCon{+c, rest}:
      match c:
        case Chr{48}:
          word_digits(rest, Nat.mul(value, 10n))
        case Chr{49}:
          word_digits(rest, Nat.add(Nat.mul(value, 10n), 1n))
        case Chr{50}:
          word_digits(rest, Nat.add(Nat.mul(value, 10n), 2n))
        case Chr{51}:
          word_digits(rest, Nat.add(Nat.mul(value, 10n), 3n))
        case Chr{52}:
          word_digits(rest, Nat.add(Nat.mul(value, 10n), 4n))
        case Chr{53}:
          word_digits(rest, Nat.add(Nat.mul(value, 10n), 5n))
        case Chr{54}:
          word_digits(rest, Nat.add(Nat.mul(value, 10n), 6n))
        case Chr{55}:
          word_digits(rest, Nat.add(Nat.mul(value, 10n), 7n))
        case Chr{56}:
          word_digits(rest, Nat.add(Nat.mul(value, 10n), 8n))
        case Chr{57}:
          word_digits(rest, Nat.add(Nat.mul(value, 10n), 9n))
        case c:
          None{}

def word_sized(valid: Bool, text: String) -> Maybe<&2, U32>:
  match valid:
    case True{}:
      word_digits(text, 0n)
    case False{}:
      None{}

def word(+text: String) -> Maybe<&2, U32>:
  word_sized(Bool.and(Nat.is_gt(String.length(text), 0n), Nat.is_le(String.length(text), 10n)), text)

def loaded_row(id: String, op: Maybe<&2, Operation>, ah: Maybe<&2, U32>, al: Maybe<&2, U32>, bh: Maybe<&2, U32>, bl: Maybe<&2, U32>) -> Loaded:
  match op ah al bh bl:
    case Some{operation} Some{ah} Some{al} Some{bh} Some{bl}:
      LoadedWork{Leaf{id, operation, Binary.from_words(ah, al), Binary.from_words(bh, bl)}}
    case op ah al bh bl:
      Invalid{}

def coefficient_digits(text: String, digits: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match text:
    case SNil{}:
      Some{digits}
    case SCon{'0', rest}:
      coefficient_digits(rest, 0 <> digits)
    case SCon{'1', rest}:
      coefficient_digits(rest, 1 <> digits)
    case SCon{'2', rest}:
      coefficient_digits(rest, 2 <> digits)
    case SCon{'3', rest}:
      coefficient_digits(rest, 3 <> digits)
    case SCon{'4', rest}:
      coefficient_digits(rest, 4 <> digits)
    case SCon{'5', rest}:
      coefficient_digits(rest, 5 <> digits)
    case SCon{'6', rest}:
      coefficient_digits(rest, 6 <> digits)
    case SCon{'7', rest}:
      coefficient_digits(rest, 7 <> digits)
    case SCon{'8', rest}:
      coefficient_digits(rest, 8 <> digits)
    case SCon{'9', rest}:
      coefficient_digits(rest, 9 <> digits)
    case text:
      None{}

def coefficient(text: String) -> Maybe<&2, List<&2, U32>>:
  match text:
    case SNil{}:
      None{}
    case text:
      coefficient_digits(text, Nil{})

def negative(text: String) -> Maybe<&2, Bool>:
  match text:
    case "+":
      Some{False{}}
    case "-":
      Some{True{}}
    case text:
      None{}

def decimal_row(id: String, negative: Maybe<&2, Bool>, digits: Maybe<&2, List<&2, U32>>, scale: Maybe<&2, Nat>) -> Loaded:
  match negative digits scale:
    case Some{negative} Some{digits} Some{scale}:
      LoadedWork{DecimalLeaf{id, negative, Decimal.Exact{digits, scale}}}
    case negative digits scale:
      Invalid{}

def ruby_row(loaded: Loaded) -> Loaded:
  match loaded:
    case LoadedWork{DecimalLeaf{id, negative, magnitude}}:
      LoadedWork{RubyDecimalLeaf{id, negative, magnitude}}
    case loaded:
      Invalid{}

def row(fields: List<&2, String>) -> Loaded:
  match fields:
    case id <> "from_decimal" <> sign <> digits <> scale <> Nil{}:
      decimal_row(id, negative(sign), coefficient(digits), Nat.read(scale))
    case id <> "from_ruby_decimal" <> sign <> digits <> scale <> Nil{}:
      ruby_row(decimal_row(id, negative(sign), coefficient(digits), Nat.read(scale)))
    case id <> op <> ah <> al <> bh <> bl <> Nil{}:
      loaded_row(id, operation(op), word(ah), word(al), word(bh), word(bl))
    case fields:
      Invalid{}

def join_rows(a: Loaded, b: Loaded) -> Loaded:
  match a b:
    case LoadedWork{x} LoadedWork{y}:
      LoadedWork{Fork{x, y}}
    case a b:
      Invalid{}

def split_fields(text: String, current: String, reversed: List<&2, String>) -> List<&2, String>:
  match text:
    case SNil{}:
      List.reverse(&2, String, String.reverse(current) <> reversed)
    case SCon{' ', rest}:
      split_fields(rest, SNil{}, String.reverse(current) <> reversed)
    case SCon{c, rest}:
      split_fields(rest, SCon{c, current}, reversed)

def load_rows_into(lines: List<&2, String>, reversed: List<&2, Loaded>) -> List<&2, Loaded>:
  match lines:
    case Nil{}:
      List.reverse(&2, Loaded, reversed)
    case SNil{} <> Nil{}:
      List.reverse(&2, Loaded, reversed)
    case line <> rest:
      load_rows_into(rest, row(split_fields(line, SNil{}, Nil{})) <> reversed)

def split_lines(text: String, current: String, reversed: List<&2, String>) -> List<&2, String>:
  match text:
    case SNil{}:
      List.reverse(&2, String, String.reverse(current) <> reversed)
    case SCon{'\n', rest}:
      split_lines(rest, SNil{}, String.reverse(current) <> reversed)
    case SCon{c, rest}:
      split_lines(rest, SCon{c, current}, reversed)

def pair_rows(rows: List<&2, Loaded>) -> List<&2, Loaded>:
  match rows:
    case a <> b <> rest:
      join_rows(a, b) <> pair_rows(rest)
    case rows:
      rows

def balance(fuel: Nat, rows: List<&2, Loaded>) -> Loaded:
  match fuel rows:
    case fuel Nil{}:
      Invalid{}
    case fuel a <> Nil{}:
      a
    case 0n rows:
      Invalid{}
    case 1n+rest rows:
      balance(rest, pair_rows(rows))

def calculate(op: Operation, +a: Binary.Float, b: Binary.Float) -> Calculation:
  match op:
    case Add{}:
      Value{Binary.add(a, b)}
    case Subtract{}:
      Value{Binary.subtract(a, b)}
    case Multiply{}:
      Value{Binary.multiply(a, b)}
    case Divide{}:
      Value{Binary.divide(a, b)}
    case RoundTrip{}:
      Value{Binary.round_trip(a)}
    case Compare{}:
      Ordering{Binary.compare(a, b)}
    case Words{}:
      RawWords{a}
    case ToExact{}:
      ExactValue{Conversion.to_exact(a)}
    case ExactRoundTrip{}:
      Value{Conversion.from_exact(Conversion.to_exact(a))}

def ordering_snapshot(order: Maybe<&2, Cmp>) -> String:
  match order:
    case None{}:
      "unordered"
    case Some{LT{}}:
      "lt"
    case Some{EQ{}}:
      "eq"
    case Some{GT{}}:
      "gt"

def snapshot(result: Calculation) -> String:
  match result:
    case Value{value}:
      Binary.snapshot(value)
    case Ordering{order}:
      ordering_snapshot(order)
    case RawWords{value}:
      Binary.render_words(Binary.words(value))
    case ExactValue{value}:
      Conversion.snapshot(value)

def execute(work: Work) -> Results:
  match work:
    case Leaf{id, operation, left, right}:
      Row{id, snapshot(calculate(operation, left, right))}
    case DecimalLeaf{id, negative, magnitude}:
      Row{id, Binary.snapshot(Conversion.from_decimal(negative, magnitude))}
    case RubyDecimalLeaf{id, negative, magnitude}:
      Row{id, Binary.snapshot(RubyConversion.from_decimal(negative, magnitude))}
    case Fork{left, right}:
      a b = execute(left) execute(right)
      Joined{a, b}

def emit(results: Results) -> IO(Unit):
  match results:
    case Row{id, value}:
      IO.print(id ++ "\t" ++ value)
    case Joined{left, right}:
      do IO<Unit>:
        emit(left)
        emit(right)

def run_loaded(loaded: Loaded) -> IO(Unit):
  match loaded:
    case LoadedWork{work}:
      emit(execute!(work))
    case Invalid{}:
      IO.die(Unit, 1, "Invalid binary64 input")

def read_data(parts: File & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (file, data) = parts
  do IO<Unit>:
    File.close(file)
    text : String <- IO.pass(String, data)
    run_loaded(balance(32n, load_rows_into(split_lines(text, SNil{}, Nil{}), Nil{})))

def read_sized(parts: File & Result<&1, &1, U32 & String, U32>) -> IO(Unit):
  (file, measured) = parts
  IO.bind(U32, Unit, IO.pass(U32, measured), size => IO.bind(Pair(File, Result<&1, &1, U32 & String, String>), Unit, File.read(file, size), read_data))

def read_opened(file: File) -> IO(Unit):
  IO.bind(Pair(File, Result<&1, &1, U32 & String, U32>), Unit, File.size(file), read_sized)

def run_args(args: List<String>) -> IO(Unit):
  match args:
    # Bend 2.0.16 omits argv[0]; 2.0.39 includes it.
    case path <> Nil{}:
      IO.bind(File, Unit, IO.try(File, File.open(path, "r")), read_opened)
    case program <> path <> Nil{}:
      IO.bind(File, Unit, IO.try(File, File.open(path, "r")), read_opened)
    case args:
      IO.die(Unit, 2, "usage: binary64-runtime INPUT")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run_args(args)
