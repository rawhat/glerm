import gleam/dynamic.{DecodeError, Decoder, Dynamic}
import gleam/function
import gleam/option.{None, Option, Some}
import gleam/result
import gleam/erlang/atom
import gleam/erlang/process.{Pid, Selector, Subject}
import gleam/otp/actor

pub type Modifier {
  Shift
  Alt
  Control
}

pub type KeyCode {
  Character(String)
  Enter
  Backspace
  Left
  Right
  Down
  Up
  Unsupported
}

pub type MouseButton {
  MouseLeft
  MouseRight
  MouseMiddle
}

pub type MouseEvent {
  MouseDown(button: MouseButton, modifier: Option(Modifier))
  MouseUp(button: MouseButton, modifier: Option(Modifier))
  Drag(button: MouseButton, modifier: Option(Modifier))
  Moved
  ScrollDown
  ScrollUp
}

pub type FocusEvent {
  Lost
  Gained
}

pub type Event {
  Focus(event: FocusEvent)
  Key(key: KeyCode, modifier: Option(Modifier))
  Mouse(event: MouseEvent)
  Resize(Int, Int)
  Unknown(tag: String, message: Dynamic)
}

fn decode_atom(val: String, actual: a) -> Decoder(a) {
  let real_atom = atom.create_from_string(val)
  let decode =
    function.compose(
      atom.from_dynamic,
      fn(maybe_atom) {
        maybe_atom
        |> result.then(fn(decoded) {
          case decoded == real_atom {
            True -> Ok(real_atom)
            False -> Error([DecodeError(val, atom.to_string(decoded), [])])
          }
        })
      },
    )
  fn(msg) {
    decode(msg)
    |> result.replace(actual)
  }
}

fn modifier_decoder() -> Decoder(Option(Modifier)) {
  let decode_some = decode_atom("some", Some)
  dynamic.any([
    decode_atom("none", None),
    function.compose(
      dynamic.tuple2(decode_some, decode_atom("shift", Shift)),
      result.replace(_, Some(Shift)),
    ),
    function.compose(
      dynamic.tuple2(decode_some, decode_atom("alt", Alt)),
      result.replace(_, Some(Alt)),
    ),
    function.compose(
      dynamic.tuple2(decode_some, decode_atom("control", Control)),
      result.replace(_, Some(Control)),
    ),
  ])
}

fn keycode_decoder() -> Decoder(KeyCode) {
  dynamic.any([
    dynamic.tuple2(decode_atom("character", Character), dynamic.string)
    |> function.compose(fn(maybe_pair) {
      case maybe_pair {
        Ok(#(_character, value)) -> Ok(Character(value))
        Error(err) -> Error(err)
      }
    }),
    decode_atom("enter", Enter),
    decode_atom("backspace", Backspace),
    decode_atom("left", Left),
    decode_atom("right", Right),
    decode_atom("down", Down),
    decode_atom("up", Up),
    decode_atom("unsupported", Unsupported),
  ])
}

fn mouse_button_decoder() -> Decoder(MouseButton) {
  dynamic.any([
    decode_atom("mouse_left", MouseLeft),
    decode_atom("mouse_right", MouseRight),
    decode_atom("mouse_middle", MouseMiddle),
  ])
}

fn mouse_event_decoder() -> Decoder(MouseEvent) {
  dynamic.any([
    dynamic.tuple3(
      decode_atom("mouse_down", MouseDown),
      mouse_button_decoder(),
      modifier_decoder(),
    )
    |> function.compose(fn(maybe_triple) {
      case maybe_triple {
        Ok(#(_mouse_down, button, modifier)) -> Ok(MouseDown(button, modifier))
        Error(err) -> Error(err)
      }
    }),
    dynamic.tuple3(
      decode_atom("mouse_up", MouseUp),
      mouse_button_decoder(),
      modifier_decoder(),
    )
    |> function.compose(fn(maybe_triple) {
      case maybe_triple {
        Ok(#(_mouse_up, button, modifier)) -> Ok(MouseUp(button, modifier))
        Error(err) -> Error(err)
      }
    }),
    dynamic.tuple3(
      decode_atom("drag", Drag),
      mouse_button_decoder(),
      modifier_decoder(),
    )
    |> function.compose(fn(maybe_triple) {
      case maybe_triple {
        Ok(#(_drag, button, modifier)) -> Ok(Drag(button, modifier))
        Error(err) -> Error(err)
      }
    }),
    decode_atom("moved", Moved),
    decode_atom("scroll_down", ScrollDown),
    decode_atom("scroll_up", ScrollUp),
  ])
}

pub fn selector() -> Selector(Event) {
  process.new_selector()
  |> process.selecting_record2(
    atom.create_from_string("focus"),
    fn(inner) {
      inner
      |> dynamic.any([decode_atom("gained", Gained), decode_atom("lost", Lost)])
      |> result.map(Focus)
      |> result.unwrap(Unknown("focus", inner))
    },
  )
  |> process.selecting_record3(
    atom.create_from_string("key"),
    fn(first, second) {
      let key_code = keycode_decoder()(first)
      let modifier = modifier_decoder()(second)
      case key_code, modifier {
        Ok(code), Ok(mod) -> Key(code, mod)
        _, _ -> Unknown("key", dynamic.from([first, second]))
      }
    },
  )
  |> process.selecting_record2(
    atom.create_from_string("mouse"),
    fn(inner) {
      inner
      |> mouse_event_decoder()
      |> result.map(Mouse)
      |> result.lazy_unwrap(fn() { Unknown("mouse", inner) })
    },
  )
  |> process.selecting_record3(
    atom.create_from_string("resize"),
    fn(first, second) {
      let columns = dynamic.int(first)
      let rows = dynamic.int(second)
      case columns, rows {
        Ok(col), Ok(rows) -> Resize(col, rows)
        _, _ -> Unknown("resize", dynamic.from([first, second]))
      }
    },
  )
}

pub external fn clear() -> Nil =
  "glerm_ffi" "clear"

pub external fn draw(commands: List(#(Int, Int, String))) -> Result(Nil, Nil) =
  "glerm_ffi" "draw"

external fn listen(pid: Pid) -> Result(Nil, Nil) =
  "glerm_ffi" "listen"

pub external fn print(data: BitString) -> Result(Nil, Nil) =
  "glerm_ffi" "print"

pub external fn size() -> Result(#(Int, Int), Nil) =
  "glerm_ffi" "size"

pub external fn move_to(column: Int, row: Int) -> Nil =
  "glerm_ffi" "move_to"

pub external fn enable_raw_mode() -> Result(Nil, Nil) =
  "glerm_ffi" "enable_raw_mode"

pub external fn disable_raw_mode() -> Result(Nil, Nil) =
  "glerm_ffi" "disable_raw_mode"

pub type ListenerMessage(user_message) {
  Term(Event)
  User(user_message)
}

pub type ListenerSubject(user_message) =
  Subject(ListenerMessage(user_message))

pub type EventSubject =
  Subject(Event)

pub type ListenerSpec(state, user_message) {
  ListenerSpec(
    init: fn() -> #(state, Option(Selector(user_message))),
    loop: fn(ListenerMessage(user_message), state) -> actor.Next(state),
  )
}

pub fn start_listener_spec(
  spec: ListenerSpec(state, user_message),
) -> Result(ListenerSubject(user_message), actor.StartError) {
  actor.start_spec(actor.Spec(
    init: fn() {
      let pid = process.self()
      let assert #(state, user_selector) = spec.init()

      let term_selector =
        selector()
        |> process.map_selector(Term)
      let selector =
        user_selector
        |> option.map(fn(user) {
          user
          |> process.map_selector(User)
          |> process.merge_selector(term_selector, _)
        })
        |> option.unwrap(term_selector)

      process.start(fn() { listen(pid) }, True)

      actor.Ready(state, selector)
    },
    init_timeout: 500,
    loop: spec.loop,
  ))
}

pub fn start_listener(
  initial_state: state,
  loop: fn(Event, state) -> actor.Next(state),
) -> Result(EventSubject, actor.StartError) {
  actor.start_spec(actor.Spec(
    init: fn() {
      let pid = process.self()
      process.start(fn() { listen(pid) }, True)
      actor.Ready(initial_state, selector())
    },
    init_timeout: 500,
    loop: loop,
  ))
}
// TODO:
//  - test?
//  - docs
