import gleam/erlang/process.{Subject}
import gleam/otp/actor
import glerm/layout.{Element}
import glerm/renderer.{Action, Render}
import glerm/event.{Event}
import gleam/function
import gleam/io

pub type Message(action) {
  Dispatch(action)
  External(Event)
  Run(Command(action))
}

pub type Command(action) {
  Command(action: fn() -> Message(action))
  Nothing
}

pub type Update(state, action) =
  fn(state, Message(action)) -> #(state, Command(action))

pub type View(state, action) =
  fn(state, Update(state, action)) -> Element

pub type Application(state, action) {
  Application(
    state: state,
    update: Update(state, action),
    view: View(state, action),
  )
}

pub fn application(
  initial_state: state,
  update: Update(state, action),
  view: View(state, action),
) -> Application(state, action) {
  Application(initial_state, update, view)
}

type State(state, action) {
  State(subject: Subject(Message(action)), state: state)
}

pub fn create(
  renderer: Subject(Action),
  application: Application(state, action),
) -> Subject(Message(action)) {
  let initial_view = application.view(application.state, application.update)
  process.send(renderer, Render(initial_view))
  let assert Ok(runtime) =
    actor.start_spec(actor.Spec(
      init: fn() {
        let subject = process.new_subject()
        let selector =
          process.new_selector()
          |> process.selecting(subject, function.identity)

        actor.Ready(State(subject, application.state), selector)
      },
      init_timeout: 500,
      loop: fn(msg, state) {
        let #(new_state, command) = application.update(state.state, msg)
        case new_state == state.state {
          True -> {
            run_command(state.subject, command)
            actor.Continue(state)
          }
          _ -> {
            let new_view = application.view(new_state, application.update)
            process.send(renderer, Render(new_view))
            run_command(state.subject, command)
            actor.Continue(State(state.subject, new_state))
          }
        }
      },
    ))
  runtime
}

fn run_command(subject: Subject(Message(action)), action: Command(action)) {
  case action {
    Nothing -> Nil
    Command(command) -> {
      process.start(
        fn() {
          let msg = command()
          process.send(subject, msg)
        },
        True,
      )
      Nil
    }
  }
}
