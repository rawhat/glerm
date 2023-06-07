import gleam/erlang/process.{Pid, Subject}
import gleam/otp/actor
import glerm/event.{Character, Control, Event, Key}
import glerm/runtime.{External, Message}
import gleam/io
import gleam/option.{Some}
import gleam/result
import glerm/renderer

external fn listen(pid: Pid) -> Result(Nil, Nil) =
  "glerm_ffi" "listen"

external fn enable_raw_mode() -> Result(Nil, Nil) =
  "glerm_ffi" "enable_raw_mode"

external fn disable_raw_mode() -> Result(Nil, Nil) =
  "glerm_ffi" "disable_raw_mode"

pub fn create(runtime: Subject(Message(action))) -> Subject(Event) {
  let assert Ok(event_listener) =
    actor.start_spec(actor.Spec(
      init: fn() {
        let subject = process.new_subject()

        let selector =
          process.new_selector()
          |> process.selecting_anything(event.decode)

        // TODO: handle errors?
        process.start(
          fn() {
            let _ = enable_raw_mode()
            let _ = listen(process.subject_owner(subject))
            disable_raw_mode()
          },
          True,
        )
        actor.Ready(Nil, selector)
      },
      init_timeout: 200,
      loop: fn(msg, state) {
        case msg {
          Key(Character("c"), Some(Control)) -> {
            renderer.clear()
            actor.Stop(process.Normal)
          }
          event -> {
            process.send(runtime, External(event))
            actor.Continue(state)
          }
        }
      },
    ))
  event_listener
}
