import gleam/bit_string
import gleam/erlang/process
import gleam/function
import gleam/option.{Some}
import gleam/string
import glerm.{Character, Control, Key}
import gleam/otp/actor

pub fn main() {
  let subject = process.new_subject()
  let selector =
    process.new_selector()
    |> process.selecting(subject, function.identity)
  let assert Ok(_) = glerm.enable_raw_mode()
  glerm.clear()
  let assert Ok(_subj) =
    glerm.start_listener(
      Nil,
      fn(msg, state) {
        case msg {
          Key(Character("c"), Some(Control)) -> {
            let assert Ok(_) = glerm.disable_raw_mode()
            process.send(subject, Nil)
            actor.Stop(process.Normal)
          }
          _ -> {
            glerm.clear()
            glerm.move_to(0, 0)
            let assert Ok(_) =
              glerm.print(bit_string.from_string(string.inspect(msg)))
            actor.Continue(state)
          }
        }
      },
    )
  process.select_forever(selector)
}
