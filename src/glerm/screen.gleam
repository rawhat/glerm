import gleam/map.{Map}

external fn get_width() -> Result(Int, Nil) =
  "Elixir.ExTermbox.Bindings" "width"

external fn get_height() -> Result(Int, Nil) =
  "Elixir.ExTermbox.Bindings" "height"

pub type Position {
  Position(column: Int, row: Int)
}

pub fn get_dimensions() -> Position {
  assert Ok(width) = get_width()
  assert Ok(height) = get_height()

  Position(width - 1, height - 1)
}

pub type Cell {
  Cell(value: String, foreground: String, background: String)
}

pub type Canvas =
  Map(Position, Cell)
