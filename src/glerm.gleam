import gleam/bit_string
import gleam/dynamic.{DecodeError, Decoder, Dynamic}
import gleam/function
import gleam/option.{Option, Some}
import gleam/result
import gleam/erlang/process.{Pid, Selector, Subject}
import gleam/otp/actor
import gleam/string
import gleam/io

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

pub type Resize {
  Resize(Int, Int)
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
  Unknown(message: Dynamic)
}

external fn do_decode_atom(src: a, val: b) -> Result(b, List(DecodeError)) =
  "glerm_ffi" "decode_atom"

fn decode_atom(val: b) -> Decoder(b) {
  fn(message: Dynamic) {
    do_decode_atom(message, val)
  }
}

fn modifier_decoder() -> Decoder(Option(Modifier)) {
  dynamic.optional(dynamic.any([
    decode_atom(Shift),
    decode_atom(Alt),
    decode_atom(Control),
  ]))
}

fn focus_decoder() -> Decoder(Event) {
  dynamic.decode1(
    Focus,
    dynamic.element(1, dynamic.any([decode_atom(Gained), decode_atom(Lost)])),
  )
}

fn keycode_decoder() -> Decoder(KeyCode) {
  dynamic.element(
    1,
    dynamic.any([
      dynamic.decode1(Character, dynamic.element(1, dynamic.string)),
      decode_atom(Enter),
      decode_atom(Backspace),
      decode_atom(Left),
      decode_atom(Right),
      decode_atom(Down),
      decode_atom(Up),
      decode_atom(Unsupported),
    ]),
  )
}

fn key_decoder() -> Decoder(Event) {
  dynamic.decode2(
    Key,
    keycode_decoder(),
    dynamic.element(2, modifier_decoder()),
  )
}

fn mouse_button_decoder() -> Decoder(MouseButton) {
  dynamic.element(
    1,
    dynamic.any([
      decode_atom(MouseLeft),
      decode_atom(MouseRight),
      decode_atom(MouseMiddle),
    ]),
  )
}

fn mouse_event_decoder() -> Decoder(MouseEvent) {
  dynamic.any([
    dynamic.decode2(
      MouseDown,
      dynamic.element(1, mouse_button_decoder()),
      dynamic.element(2, modifier_decoder()),
    ),
    dynamic.decode2(
      MouseUp,
      dynamic.element(1, mouse_button_decoder()),
      dynamic.element(2, modifier_decoder()),
    ),
    dynamic.decode2(
      Drag,
      dynamic.element(1, mouse_button_decoder()),
      dynamic.element(2, modifier_decoder()),
    ),
    dynamic.element(1, decode_atom(Moved)),
    dynamic.element(1, decode_atom(ScrollDown)),
    dynamic.element(1, decode_atom(ScrollUp)),
  ])
}

fn mouse_decoder() -> Decoder(Event) {
  dynamic.decode1(Mouse, mouse_event_decoder())
}

pub fn selector() -> Selector(Event) {
  process.new_selector()
  // TODO:  It would be nicer to use `process.selecting_recordN`, but those
  // don't handle decoders very nicely. If I find a workaround, or some other
  // functions are added, swap to that
  |> process.selecting_anything(fn(message) {
    let decoder = dynamic.any([focus_decoder(), key_decoder(), mouse_decoder()])
    decoder(message)
    |> result.unwrap(Unknown(message))
  })
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
