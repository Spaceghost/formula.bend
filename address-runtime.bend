import Base
import ./src/address.bend as Address

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Address.render_parsed_a1(Address.parse_a1("$A1", 1n, 1n), 4n, 3n, 100n, 100n))
    IO.print(Address.render_parsed_a1(Address.parse_a1("A$1", 1n, 1n), 4n, 3n, 100n, 100n))
    IO.print(Address.render_parsed_r1c1(Address.parse_a1("$A1", 1n, 1n)))
    IO.print(Address.render_parsed_a1(Address.parse_r1c1("R[-1]C[2]"), 5n, 5n, 100n, 100n))
    IO.print(Address.render_parsed_a1(Address.parse_r1c1("RC"), 5n, 5n, 100n, 100n))
    IO.print(Address.render_parsed_a1(Address.parse_a1("Z1", 0n, 0n), 0n, 1n, 100n, 100n))
    IO.print(Address.render_parsed_a1(Address.parse_a1("A1", 1n, 1n), 0n, 0n, 100n, 100n))
    IO.print(Address.render_parsed_a1(Address.parse_r1c1("R[]C1"), 0n, 0n, 100n, 100n))
