import Base

# A1 references store a coordinate and an independent anchor on each axis.
# Copying shifts only unlocked axes. Coordinates are zero-based internally.
type Axis is Data:
  Absolute{coordinate: Nat}
  Relative{coordinate: Nat}

type Reference is Data:
  Cell{row: Axis, column: Axis}

def shift_axis(axis: Axis, delta: Nat) -> Axis:
  match axis:
    case Absolute{n}:
      Absolute{n}
    case Relative{n}:
      Relative{Nat.add(n, delta)}

# Forward-copy primitive; backward copying and bounds validation are pending.
def copy_forward(ref: Reference, rows: Nat, columns: Nat) -> Reference:
  match ref:
    case Cell{r, c}:
      rr cc = shift_axis(r, rows) shift_axis(c, columns)
      Cell{rr, cc}
