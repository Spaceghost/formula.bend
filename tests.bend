import Base
import ./src/core.bend as Core
import ./src/reference.bend as Ref

# Concrete regression fixtures complement the universal laws.
def arithmetic() -> {Core.evaluate(Core.Multiply{Core.Add{Core.Literal{Core.Number{5n}}, Core.Literal{Core.Number{2n}}}, Core.Literal{Core.Number{6n}}}) == Core.Number{42n} : Core.Value}:
  {==}

def unused_failure() -> {Core.evaluate(Core.If{Core.Literal{Core.Logical{True{}}}, Core.Literal{Core.Number{7n}}, Core.Literal{Core.Failure{"unbound"}}}) == Core.Number{7n} : Core.Value}:
  {==}

def left_error() -> {Core.evaluate(Core.Add{Core.Literal{Core.Failure{"left"}}, Core.Literal{Core.Failure{"right"}}}) == Core.Failure{"left"} : Core.Value}:
  {==}

def both_relative() -> {Ref.copy_forward(Ref.Cell{Ref.Relative{0n}, Ref.Relative{0n}}, 2n, 3n) == Ref.Cell{Ref.Relative{2n}, Ref.Relative{3n}} : Ref.Reference}:
  {==}

def column_absolute() -> {Ref.copy_forward(Ref.Cell{Ref.Relative{0n}, Ref.Absolute{0n}}, 2n, 3n) == Ref.Cell{Ref.Relative{2n}, Ref.Absolute{0n}} : Ref.Reference}:
  {==}

def both_absolute() -> {Ref.copy_forward(Ref.Cell{Ref.Absolute{0n}, Ref.Absolute{0n}}, 2n, 3n) == Ref.Cell{Ref.Absolute{0n}, Ref.Absolute{0n}} : Ref.Reference}:
  {==}
