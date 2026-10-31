import Base
import ../src/core.bend as Core
import ../src/unicode.bend as Unicode
import ./corpus-wire.bend as Wire

def code_tail(text: String) -> String:
  match text:
    case SNil{}:
      ""
    case SCon{c, rest}:
      "," ++ U32.show(Char.to_u32(c)) ++ code_tail(rest)

def codes(text: String) -> String:
  match text:
    case SNil{}:
      ""
    case SCon{c, rest}:
      U32.show(Char.to_u32(c)) ++ code_tail(rest)

def check_chars(text: String) -> IO(Unit):
  match text:
    case SNil{}:
      IO.pure(Unit, Unit{})
    case SCon{+c, rest}:
      do IO<Unit>:
        IO.print(U32.show(Char.to_u32(c)) ++ "\t" ++ Bool.pick(String, Unicode.is_alpha(c), "1", "0") ++ "\t" ++ Bool.pick(String, Unicode.is_word(c), "1", "0") ++ "\t" ++ codes(Unicode.lower_char(c)) ++ "\t" ++ codes(Unicode.fold_char(c)))
        check_chars(rest)

def decoded(result: Wire.Decoded) -> IO(Unit):
  match result:
    case Wire.Value{Core.TextValue{text}}:
      check_chars(text)
    case Wire.Invalid{message}:
      IO.die(Unit, 1, message)
    case result:
      IO.die(Unit, 1, "Unicode checks need a text payload")

def read_data(parts: File & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (file, data) = parts
  do IO<Unit>:
    File.close(file)
    text : String <- IO.pass(String, data)
    decoded(Wire.decode(text))

def read_sized(parts: File & Result<&1, &1, U32 & String, U32>) -> IO(Unit):
  (file, measured) = parts
  IO.bind(U32, Unit, IO.pass(U32, measured), size => IO.bind(Pair(File, Result<&1, &1, U32 & String, String>), Unit, File.read(file, size), read_data))

def read_opened(file: File) -> IO(Unit):
  IO.bind(Pair(File, Result<&1, &1, U32 & String, U32>), Unit, File.size(file), read_sized)

def run_args(args: List<String>) -> IO(Unit):
  match args:
    case program <> path <> Nil{}:
      IO.bind(File, Unit, IO.try(File, File.open(path, "r")), read_opened)
    case args:
      IO.die(Unit, 2, "usage: unicode-runtime INPUT")

def main() -> IO(Unit):
  IO.bind(List<String>, Unit, IO.args(), run_args)
