import gleam/erlang/process
import gleam/function
import glerm/event_manager
import glerm/layout.{
  Border, Padding, Rounded, horizontal_box, text, vertical_box,
}
import glerm/renderer.{Render}

external fn termbox_init() -> Nil =
  "Elixir.ExTermbox.Bindings" "init"

// external fn write_character(row: Int, col: Int, character: Int) -> Nil =
//   "Elixir.Glerm.Helpers" "write_character"

pub fn main() {
  termbox_init()

  let renderer = renderer.create()
  let event_manager = event_manager.create(renderer)

  let selector =
    process.new_selector()
    |> process.selecting_anything(function.identity)

  process.monitor_process(process.subject_owner(event_manager))

  let test_layout =
    horizontal_box(
      [],
      [
        text(
          [Border(Rounded("white")), Padding(5)],
          "this is a long string that should wrap in the box, but we'll see if that actually works",
        ),
        text([Border(Rounded("red"))], "world"),
        vertical_box(
          [],
          [
            text([Border(Rounded("green"))], "what"),
            text([Border(Rounded("yellow"))], "up"),
          ],
        ),
      ],
    )

  process.send(renderer, Render(test_layout))

  process.select_forever(selector)
}
