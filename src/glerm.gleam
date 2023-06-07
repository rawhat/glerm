import gleam/erlang/charlist
import gleam/erlang/process
import glerm/event_manager
import gleam/function
import glerm/layout.{
  LineBreak, Percent, Pixels, Rounded, Word, border, height, horizontal_box,
  line_break, padding, row, style, text, text_style, vertical_box, width,
}
import glerm/renderer
import glerm/event.{Backspace, Character, Control, Key}
import glerm/runtime.{
  Application, Command, Dispatch, External, Nothing, application,
}
import gleam/string
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{Option, Some}
import gleam_community/ansi

pub fn initialize(application: Application(state, action)) -> Nil {
  let renderer = renderer.create()
  let runtime = runtime.create(renderer, application)
  let _event_manager = event_manager.create(runtime)

  Nil
}

pub type State {
  State(input: String, results: List(String), selected: Option(Int))
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
  UpdateSelected(index: Int)
}

pub fn main() {
  let selector =
    process.new_selector()
    |> process.selecting_anything(function.identity)

  // process.monitor_process(process.subject_owner(event_manager))
  let app =
    application(
      State("", [], option.None),
      fn(state, action) {
        case action {
          Dispatch(SetResults(results)) -> {
            let selected = case results {
              [] -> option.None
              [_, ..] -> option.Some(0)
            }
            #(State(..state, results: results, selected: selected), Nothing)
          }
          Dispatch(UpdateSelected(index)) -> #(
            State(..state, selected: option.Some(index)),
            Nothing,
          )
          External(Key(Character("p"), Some(Control))) ->
            case state.results, state.selected {
              [], _ -> #(state, Nothing)
              [_, ..], option.Some(n) if n == 0 -> #(state, Nothing)
              [_, ..], option.Some(_n) -> #(
                state,
                Command(fn() {
                  state.selected
                  |> option.map(fn(selected) { selected - 1 })
                  |> option.unwrap(0)
                  |> UpdateSelected
                  |> Dispatch
                }),
              )
            }
          External(Key(Character("n"), Some(Control))) ->
            case list.length(state.results), state.selected {
              0, _ -> #(state, Nothing)
              length, option.Some(n) ->
                case n == length - 2 {
                  True -> #(state, Nothing)
                  _ -> #(
                    state,
                    Command(fn() {
                      state.selected
                      |> option.map(fn(selected) { selected + 1 })
                      |> option.unwrap(0)
                      |> UpdateSelected
                      |> Dispatch
                    }),
                  )
                }
            }
          External(Key(Character(key), ..)) -> {
            let new_state =
              State(..state, input: state.input <> key, results: [])
            let cmd = case string.length(new_state.input) >= 3 {
              True ->
                Command(fn() {
                  let results = grep(new_state.input)
                  Dispatch(SetResults(results))
                })
              False -> Nothing
            }
            #(new_state, cmd)
          }
          External(Key(Backspace, ..)) -> {
            let new_state =
              State(
                ..state,
                input: string.slice(
                  state.input,
                  0,
                  int.max(string.length(state.input) - 1, 0),
                ),
                results: [],
              )
            let cmd = case string.length(new_state.input) >= 3 {
              True ->
                Command(fn() {
                  let results = grep(new_state.input)
                  Dispatch(SetResults(results))
                })
              False -> Nothing
            }
            #(new_state, cmd)
          }
          _ -> #(state, Nothing)
        }
      },
      fn(state, _update) {
        vertical_box(
          style(),
          [
            vertical_box(
              style()
              |> border(Rounded(ansi.white)),
              list.index_map(
                state.results,
                fn(index, result) {
                  row(
                    option.map(
                      state.selected,
                      fn(selected) {
                        case selected == index {
                          True ->
                            text_style(
                              style(),
                              function.compose(ansi.bg_magenta, ansi.black),
                            )
                          False -> style()
                        }
                      },
                    )
                    |> option.unwrap(style()),
                    result,
                  )
                },
              ),
            ),
            text(
              style()
              |> border(Rounded(ansi.red))
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
