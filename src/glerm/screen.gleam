import gleam/function
import gleam/map.{Map}

external fn get_size() -> Result(#(Int, Int), Nil) =
  "glerm_ffi" "size"

pub type Position {
  Position(column: Int, row: Int)
}

pub fn get_dimensions() -> Position {
  let assert Ok(#(columns, rows)) = get_size()

  Position(columns - 1, rows - 1)
}

pub type AnsiStyle =
  fn(String) -> String

pub type Cell {
  Cell(value: String, style: AnsiStyle)
}

pub fn empty_cell() -> Cell {
  Cell(value: " ", style: function.identity)
}

pub type Canvas =
  Map(Position, Cell)
