import gleam/dynamic.{Dynamic}
import gleam/erlang/process.{Pid, Subject}
import gleam/io
import gleam/otp/actor
import glerm/renderer.{
  Action, Backspace, Backward, Down, Forward, MoveCursor, Return, Up,
  WriteCharacter, WriteString,
}

pub type Event {
  Event(char: Int, key: Int)
}

external fn decode_event(event: Dynamic) -> Event =
  "Elixir.Glerm.Helpers" "convert_event"

external fn start_event_manager() -> Result(Pid, Nil) =
  "Elixir.ExTermbox.EventManager" "start_link"

external fn subscribe(pid: Pid) -> Nil =
  "Elixir.ExTermbox.EventManager" "subscribe"

external fn shutdown() -> Nil =
  "Elixir.ExTermbox.Bindings" "shutdown"

pub fn create(renderer: Subject(Action)) -> Subject(Event) {
  assert Ok(_pid) = start_event_manager()
  assert Ok(event_listener) =
    actor.start_spec(actor.Spec(
      init: fn() {
        let subject = process.new_subject()

        let selector =
          process.new_selector()
          |> process.selecting_anything(decode_event)

        subscribe(process.subject_owner(subject))
        actor.Ready(Nil, selector)
      },
      init_timeout: 200,
      loop: fn(msg, state) {
        case msg {
          Event(0, 3) -> {
            shutdown()
            actor.Stop(process.Normal)
          }
          Event(char, 0) -> {
            process.send(renderer, WriteCharacter(char))
            actor.Continue(state)
          }
          Event(0, 32) -> {
            process.send(renderer, WriteString(" "))
            actor.Continue(state)
          }
          Event(0, 127) -> {
            process.send(renderer, Backspace)
            actor.Continue(state)
          }
          Event(0, 13) -> {
            process.send(renderer, Return)
            actor.Continue(state)
          }
          Event(0, 65517) -> {
            process.send(renderer, MoveCursor(Up))
            actor.Continue(state)
          }
          Event(0, 65516) -> {
            process.send(renderer, MoveCursor(Down))
            actor.Continue(state)
          }
          Event(0, 65515) -> {
            process.send(renderer, MoveCursor(Backward))
            actor.Continue(state)
          }
          Event(0, 65514) -> {
            process.send(renderer, MoveCursor(Forward))
            actor.Continue(state)
          }
          Event(char, key) -> {
            io.debug(#("got a char", char, "and key", key))
            actor.Continue(state)
          }
        }
      },
    ))
  event_listener
}
