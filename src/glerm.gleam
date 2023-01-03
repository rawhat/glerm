import gleam/erlang/charlist
import gleam/erlang/process
import gleam/function
import glerm/event_manager
import glerm/layout.{
  LineBreak, Percent, Pixels, Rounded, Word, border, height, horizontal_box,
  line_break, padding, row, style, text, vertical_box, width,
}
import glerm/renderer
import glerm/event.{Backspace, Key}
import glerm/runtime.{
  Application, Command, Dispatch, External, None, application,
}
import gleam/string
import gleam/io
import gleam/list

external fn termbox_init() -> Nil =
  "Elixir.ExTermbox.Bindings" "init"

// external fn write_character(row: Int, col: Int, character: Int) -> Nil =
//   "Elixir.Glerm.Helpers" "write_character"

pub fn initialize(application: Application(state, action)) -> Nil {
  termbox_init()

  let renderer = renderer.create()
  let runtime = runtime.create(renderer, application)
  let _event_manager = event_manager.create(runtime)

  Nil
}

pub type State {
  State(input: String, results: List(String))
}

external fn os_cmd(cmd: charlist.Charlist) -> String =
  "os" "cmd"

fn grep(str: String) -> List(String) {
  "rg --color=never --no-heading --with-filename --line-number --column --smart-case '" <> str <> "'"
  |> charlist.from_string
  |> os_cmd
  |> string.split(on: "\n")
}

pub type Action {
  SetResults(results: List(String))
}

pub fn main() {
  let selector =
    process.new_selector()
    |> process.selecting_anything(function.identity)

  // process.monitor_process(process.subject_owner(event_manager))
  let app =
    application(
      State("", []),
      fn(state, action) {
        case action {
          Dispatch(SetResults(results)) -> #(
            State(..state, results: results),
            None,
          )
          External(Key(key, ..)) -> {
            let new_state = State(input: state.input <> key, results: [])
            let cmd = case string.length(new_state.input) >= 3 {
              True ->
                Command(fn() {
                  let results = grep(new_state.input)
                  // io.debug(#("results", results))
                  Dispatch(SetResults(results))
                })
              False -> None
            }
            #(new_state, cmd)
          }
          External(Backspace) -> {
            let new_state =
              State(
                input: string.slice(
                  state.input,
                  0,
                  string.length(state.input) - 1,
                ),
                results: [],
              )
            let cmd = case string.length(new_state.input) >= 3 {
              True ->
                Command(fn() {
                  let results = grep(new_state.input)
                  Dispatch(SetResults(results))
                })
              False -> None
            }
            #(new_state, cmd)
          }
          _ -> #(state, None)
        }
      },
      fn(state, _update) {
        vertical_box(
          style(),
          [
            vertical_box(
              style()
              |> border(Rounded("white")),
              list.map(state.results, fn(result) { row(style(), result) }),
            ),
            text(
              style()
              |> border(Rounded("red"))
              |> height(Pixels(2)),
              state.input <> "█",
            ),
          ],
        )
      },
    )

  // horizontal_box(
  //   style()
  //   |> border(Rounded("blue")),
  //   [
  //     text(
  //       style()
  //       |> border(Rounded("white"))
  //       |> padding(5)
  //       |> line_break(Word)
  //       |> width(Percent(50)),
  //       "this is a long string that should wrap in the box, but we'll see if that actually works",
  //     ),
  //     text(
  //       style()
  //       |> border(Rounded("red"))
  //       |> width(Pixels(30)),
  //       "world",
  //     ),
  //     vertical_box(
  //       style(),
  //       [
  //         text(
  //           style()
  //           |> border(Rounded("green"))
  //           |> height(Percent(75)),
  //           "what",
  //         ),
  //         text(
  //           style()
  //           |> border(Rounded("yellow")),
  //           "up",
  //         ),
  //       ],
  //     ),
  //   ],
  // )
  // vertical_box(
  //   [],
  //   [
  //     vertical_box(
  //       [Border(Rounded("white"))],
  //       list.map(state.results, fn(result) { text([], result) }),
  //     ),
  //     text([Border(Rounded("red"))], state.input <> "█"),
  //   ],
  // )
  initialize(app)

  process.select_forever(selector)
}
