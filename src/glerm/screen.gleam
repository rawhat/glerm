import gleam/map.{Map}

external fn get_width() -> Result(Int, Nil) =
  "Elixir.ExTermbox.Bindings" "width"

external fn get_height() -> Result(Int, Nil) =
  "Elixir.ExTermbox.Bindings" "height"

pub type Position {
  Position(x: Int, y: Int)
}

pub fn get_dimensions() -> Position {
  assert Ok(width) = get_width()
  assert Ok(height) = get_height()

  Position(height - 1, width - 1)
}

pub type Cell {
  Cell(value: String, color: String)
}

pub type Canvas =
  Map(Position, Cell)
