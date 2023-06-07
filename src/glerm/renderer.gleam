import gleam/erlang/atom.{Atom}
import gleam/erlang/charlist.{Charlist}
import gleam/erlang/process.{Subject}
import gleam/function
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/map
import glerm/layout.{Element}
import gleam/result
import glerm/screen.{Canvas, Cell, Position}
import gleam_community/ansi

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
  let assert Ok(renderer) =
    actor.start_spec(actor.Spec(
      init: fn() {
        let selector = process.new_selector()
        let initial_state =
          RendererState(cursor: Position(0, 0), canvas: map.new())
        clear()
        actor.Ready(initial_state, selector)
      },
      init_timeout: 50,
      loop: fn(msg, state) {
        let updated_state = case msg {
          RenderText(position, text) ->
            RendererState(
              ..state,
              canvas: map.insert(
                state.canvas,
                position,
                Cell(text, function.identity),
              ),
            )
          WriteCharacter(char) -> {
            let new_cursor = move_cursor(state.cursor, Forward)
            RendererState(
              canvas: map.insert(
                state.canvas,
                state.cursor,
                Cell(char_code_to_string(char), function.identity),
              ),
              cursor: new_cursor,
            )
          }
          WriteString(str) -> {
            let new_cursor = move_cursor(state.cursor, Forward)
            RendererState(
              canvas: map.insert(
                state.canvas,
                state.cursor,
                Cell(str, function.identity),
              ),
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
        render(state.canvas, updated_state.canvas)
        actor.Continue(updated_state)
      },
    ))
  renderer
}

fn render(prev: Canvas, next: Canvas) -> Nil {
  let empty_cells =
    prev
    |> map.to_list
    |> list.filter(fn(pair) {
      let assert #(position, _cell) = pair
      next
      |> map.get(position)
      |> result.is_error
    })
    |> list.map(fn(pair) {
      let assert #(position, _cell) = pair
      #(position, screen.empty_cell())
    })
  next
  |> map.to_list
  |> list.filter(fn(pair) {
    let assert #(position, value) = pair
    case map.get(prev, position) {
      Ok(prev_value) -> value != prev_value
      _ -> True
    }
  })
  |> list.append(empty_cells)
  |> list.each(fn(pair) {
    let assert #(position, cell) = pair
    let text = cell.style(cell.value)
    move_to(position.column, position.row)
    print(text)
  })
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

external fn binary_to_list(bs: BitString) -> String =
  "erlang" "binary_to_list"

fn char_code_to_string(code: Int) -> String {
  binary_to_list(<<code>>)
}

pub external fn clear() -> Nil =
  "glerm_ffi" "clear"

external fn move_to(column: Int, row: Int) -> Nil =
  "glerm_ffi" "move_to"

external fn print(data: String) -> Nil =
  "glerm_ffi" "print"

external fn draw(commands: List(#(Int, Int, String))) -> Result(Nil, Nil) =
  "glerm_ffi" "draw"
