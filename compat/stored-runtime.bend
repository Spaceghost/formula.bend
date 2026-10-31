import ./stored_checked_api.bend as CheckedApi
import ./stored_dependencies_api.bend as DependencyApi
import Base
import ../src/core.bend as Core
import ./corpus-wire.bend as Wire
import ./stored_api.bend as Api

type Results is Data:
  Result{id: String, snapshot: String}
  Joined{left: Results, right: Results}
  Invalid{message: String}

def execute(operation: String, id: String, input: Core.Value) -> Results:
  match operation:
    case "stored_value":
      Result{id, Api.snapshot(input)}
    case "stored_checked":
      Result{id, CheckedApi.snapshot(input, False{})}
    case "stored_checked_message":
      Result{id, CheckedApi.snapshot(input, True{})}
    case "stored_dependencies":
      Result{id, DependencyApi.snapshot(input)}
    case operation:
      Invalid{"Unknown stored corpus operation"}

def row(value: Core.Value) -> Results:
  match value:
    case Core.ArrayCons{Core.TextValue{id}, Core.ArrayCons{Core.TextValue{formula}, Core.ArrayCons{Core.TextValue{operation}, Core.ArrayCons{Core.ArrayCons{Core.ArrayCons{Core.TextValue{"input"}, Core.ArrayCons{input, Core.ArrayNil{}}}, Core.ArrayNil{}}, Core.ArrayCons{Core.Logical{sensitive}, Core.ArrayCons{Core.Logical{False{}}, Core.ArrayNil{}}}}}}}:
      execute(operation, id, input)
    case value:
      Invalid{"Invalid stored-value corpus row"}

def combine(left: Results, right: Results) -> Results:
  match left right:
    case Invalid{message} right:
      Invalid{message}
    case left Invalid{message}:
      Invalid{message}
    case left right:
      Joined{left, right}

def evaluate(batch: Core.Value) -> Results:
  match batch:
    case Core.ArgumentValue{value}:
      row(value)
    case Core.ArgumentPair{left, right}:
      a b = evaluate(left) evaluate(right)
      combine(a, b)
    case batch:
      Invalid{"Empty or malformed stored-value corpus"}

def emit(results: Results) -> IO(Unit):
  match results:
    case Result{id, snapshot}:
      IO.print(id ++ "\t" ++ snapshot)
    case Joined{left, right}:
      do IO<Unit>:
        emit(left)
        emit(right)
    case Invalid{message}:
      IO.die(Unit, 1, message)

def run_decoded(decoded: Wire.Decoded) -> IO(Unit):
  match decoded:
    case Wire.Value{value}:
      emit(evaluate!(Core.collection_batch(value)))
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

def run_args(args: List<String>) -> IO(Unit):
  match args:
    case program <> path <> Nil{}:
      IO.bind(File, Unit, IO.try(File, File.open(path, "r")), read_opened)
    case args:
      IO.die(Unit, 2, "usage: stored-runtime INPUT")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run_args(args)
