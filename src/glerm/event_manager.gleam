import gleam/erlang/process.{Pid, Subject}
import gleam/otp/actor
import glerm/event.{Event, Key}
import glerm/runtime.{External, Message}
import gleam/io

external fn start_event_manager() -> Result(Pid, Nil) =
  "Elixir.ExTermbox.EventManager" "start_link"

external fn subscribe(pid: Pid) -> Nil =
  "Elixir.ExTermbox.EventManager" "subscribe"

external fn shutdown() -> Nil =
  "Elixir.ExTermbox.Bindings" "shutdown"

pub fn create(runtime: Subject(Message(action))) -> Subject(Event) {
  assert Ok(_pid) = start_event_manager()
  assert Ok(event_listener) =
    actor.start_spec(actor.Spec(
      init: fn() {
        let subject = process.new_subject()

        let selector =
          process.new_selector()
          |> process.selecting_anything(event.decode)
          |> process.map_selector(event.convert)

        subscribe(process.subject_owner(subject))
        actor.Ready(Nil, selector)
      },
      init_timeout: 200,
      loop: fn(msg, state) {
        case msg {
          Key("c", True, False, False) -> {
            shutdown()
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
