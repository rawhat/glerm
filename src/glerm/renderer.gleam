import gleam/erlang/atom.{Atom}
import gleam/erlang/charlist.{Charlist}
import gleam/erlang/process.{Subject}
import gleam/int
import gleam/list
import gleam/otp/actor
import gleam/map
import glerm/layout.{Element}
import glerm/screen.{Canvas, Cell, Position}

pub type RendererState {
  RendererState(cursor: Position, canvas: Canvas)
}

pub type Direction {
  Forward
  Backward
  Up
  Down
}

pub type Action {
  RenderText(from: Position, text: String)
  WriteCharacter(char: Int)
  WriteString(string: String)
  Backspace
  Return
  MoveCursor(Direction)
  Render(Element)
}

pub fn create() -> Subject(Action) {
  assert Ok(renderer) =
    actor.start_spec(actor.Spec(
      init: fn() {
        let selector = process.new_selector()
        let initial_state =
          RendererState(cursor: Position(0, 0), canvas: map.new())
        render(initial_state.canvas)
        actor.Ready(initial_state, selector)
      },
      init_timeout: 50,
      loop: fn(msg, state) {
        let updated_state = case msg {
          RenderText(position, text) ->
            RendererState(
              ..state,
              canvas: map.insert(state.canvas, position, Cell(text, "white")),
            )
          WriteCharacter(char) -> {
            let new_cursor = move_cursor(state.cursor, Forward)
            RendererState(
              canvas: map.insert(
                state.canvas,
                state.cursor,
                Cell(char_code_to_string(char), "white"),
              ),
              cursor: new_cursor,
            )
          }
          WriteString(str) -> {
            let new_cursor = move_cursor(state.cursor, Forward)
            RendererState(
              canvas: map.insert(state.canvas, state.cursor, Cell(str, "white")),
              cursor: new_cursor,
            )
          }
          Backspace -> {
            let new_cursor = move_cursor(state.cursor, Backward)
            RendererState(
              canvas: map.delete(state.canvas, state.cursor),
              cursor: new_cursor,
            )
          }
          Return -> {
            let Position(x, ..) = screen.get_dimensions()
            let new_cursor = Position(int.min(x, state.cursor.column + 1), 0)
            RendererState(..state, cursor: new_cursor)
          }
          MoveCursor(direction) -> {
            let new_cursor = move_cursor(state.cursor, direction)
            RendererState(..state, cursor: new_cursor)
          }
          Render(tree) -> RendererState(..state, canvas: layout.build(tree))
        }
        render(updated_state.canvas)
        actor.Continue(updated_state)
      },
    ))
  renderer
}

fn render(canvas: Canvas) -> Nil {
  clear()

  canvas
  |> map.to_list
  |> list.each(fn(pair) {
    assert #(position, cell) = pair
    let color = atom.create_from_string(cell.color)
    write_charlist(
      position.column,
      position.row,
      charlist.from_string(cell.value),
      color,
    )
  })
  present()
}

fn move_cursor(existing: Position, direction: Direction) -> Position {
  let Position(columns, rows) = screen.get_dimensions()
  case direction {
    Forward -> {
      let at_column_end = existing.column + 1 > columns
      let at_row_end = existing.row + 1 > rows
      case at_column_end, at_row_end {
        False, _ -> Position(..existing, column: existing.column + 1)
        True, False -> Position(column: 0, row: existing.row + 1)
        True, True -> existing
      }
    }
    Backward -> {
      let at_column_beginning = existing.column - 1 < 0
      let at_row_beginning = existing.row - 1 < 0
      case at_column_beginning, at_row_beginning {
        True, False -> Position(column: columns, row: existing.row - 1)
        True, True -> existing
        False, _ -> Position(..existing, column: existing.column - 1)
      }
    }
    Up -> Position(..existing, row: int.max(0, existing.row - 1))
    Down -> Position(..existing, row: int.min(rows - 1, existing.row + 1))
  }
}

pub external fn char_code_to_string(code: Int) -> String =
  "Elixir.Glerm.Helpers" "char_code_to_string"

external fn clear() -> Nil =
  "Elixir.ExTermbox.Bindings" "clear"

external fn write_charlist(
  row: Int,
  col: Int,
  charlist: Charlist,
  color: Atom,
) -> Nil =
  "Elixir.Glerm.Helpers" "write_charlist"

external fn present() -> Nil =
  "Elixir.ExTermbox.Bindings" "present"

fn draw_cursor(position: Position) -> Nil {
  write_charlist(
    position.column,
    position.row,
    charlist.from_string("█"),
    atom.create_from_string("white"),
  )
}
