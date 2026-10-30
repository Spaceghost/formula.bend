import Base
import ../src/core.bend as Core
import ../src/parser.bend as Parser
import ../src/string.bend as StringOps
import ./gpu-corpus.bend as Gpu
import ./corpus-wire.bend as Wire
import ./corpus-input.bend as Input

def run_work(loaded: Input.Loaded) -> IO(Unit):
  match loaded:
    case Input.LoadedWork{work}:
      Gpu.emit(Gpu.evaluate!(work))
    case Input.Invalid{message}:
      IO.die(Unit, 1, message)

def run_decoded(decoded: Wire.Decoded) -> IO(Unit):
  match decoded:
    case Wire.Value{value}:
      run_work(Input.load(value))
    case Wire.Invalid{message}:
      IO.die(Unit, 1, message)

def read_data(parts: File & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (file, data) = parts
  do IO<Unit>:
    File.close(file)
    text : String <- IO.pass(String, data)
    run_decoded(Wire.decode(text))

def read_sized(parts: File & Result<&1, &1, U32 & String, U32>) -> IO(Unit):
  (file, measured) = parts
  IO.bind(U32, Unit, IO.pass(U32, measured), size => IO.bind(Pair(File, Result<&1, &1, U32 & String, String>), Unit, File.read(file, size), read_data))

def read_opened(file: File) -> IO(Unit):
  IO.bind(Pair(File, Result<&1, &1, U32 & String, U32>), Unit, File.size(file), read_sized)

def read_file(path: String) -> IO(Unit):
  IO.bind(File, Unit, IO.try(File, File.open(path, "r")), read_opened)

def run_args(args: List<String>) -> IO(Unit):
  match args:
    case program <> path <> Nil{}:
      read_file(path)
    case args:
      IO.die(Unit, 2, "usage: corpus-runtime INPUT")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run_args(args)
