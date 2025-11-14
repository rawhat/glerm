import gleam/dynamic
import gleam/erlang/atom
import gleam/erlang/process
import gleam/option.{type Option}
import gleam/otp/actor

/// These represent the noted keys being held down when another action is taken,
/// like pressing another key or mouse button. For certain keys, things like
/// `Shift` will not be set, but instead return something like `A`.
pub type Modifier {
  Shift
  Alt
  Control
}

/// A particular keyboard key that was pressed. Either a character with its
/// value, or a special key. The `Unsupported` is for things like `PageUp`, etc
/// that I'm just not handling yet.
pub type KeyCode {
  Character(String)
  Function(Int)
  Enter
  Escape
  Backspace
  Left
  Right
  Down
  Up
  Tab
  BackTab
  Unsupported
}

/// Which mouse button was pressed. These are prefixed with `Mouse` in order to
/// avoid conflicting with the arrow keys defined in `KeyCode`.
pub type MouseButton {
  MouseLeft
  MouseRight
  MouseMiddle
}

/// The possible types of mouse events. I think most of these will also
/// have the mouse cursor position attached. That is not supported at the moment.
pub type MouseEvent {
  MouseDown(button: MouseButton, col: Int, row: Int, modifier: Option(Modifier))
  MouseUp(button: MouseButton, modifier: Option(Modifier))
  Drag(button: MouseButton, col: Int, row: Int, modifier: Option(Modifier))
  Moved(col: Int, row: Int)
  ScrollDown
  ScrollUp
}

/// When the terminal window is focused or un-focused.
pub type FocusEvent {
  Lost
  Gained
}

/// The possible events coming back from the terminal. `Unknown` should
/// realistically never happen, since this library controls both ends of the
/// message passing.
pub type Event {
  Focus(event: FocusEvent)
  Key(key: KeyCode, modifier: Option(Modifier))
  Mouse(event: MouseEvent)
  Resize(Int, Int)
}

/// The events from the NIF are sent as messages to the calling process. These
/// do not go through a `process.Subject`, so they need to be explicitly
/// extracted from the mailbox. This selector will grab the given `Event`s for
/// each message that comes in.
pub fn selector() -> process.Selector(Event) {
  process.new_selector()
  |> process.select_record(atom.create("focus"), 1, convert_event2)
  |> process.select_record(atom.create("key"), 2, convert_event3)
  |> process.select_record(atom.create("mouse"), 1, convert_event2)
  |> process.select_record(atom.create("mouse"), 2, convert_event3)
  |> process.select_record(atom.create("resize"), 2, convert_event3)
}

@external(erlang, "glerm_ffi", "convert_event")
fn convert_event2(d: dynamic.Dynamic) -> Event

@external(erlang, "glerm_ffi", "convert_event")
fn convert_event3(d: dynamic.Dynamic) -> Event

/// Fully clears the terminal window
@external(erlang, "glerm_ffi", "clear")
pub fn clear() -> Nil

/// Write some string to the screen at the given #(column, row) coordinate
@external(erlang, "glerm_ffi", "draw")
pub fn draw(commands: List(#(Int, Int, String))) -> Result(Nil, Nil)

/// This is the "meat" of the library. This will fire up the NIF, which spawns
/// a thread to read for terminal events. The `Pid` provided here is where the
/// messages will be sent.
@external(erlang, "glerm_ffi", "listen")
fn listen(pid: process.Pid) -> Result(Nil, Nil)

/// Writes the given text wherever the cursor is
@external(erlang, "glerm_ffi", "print")
pub fn print(data: BitArray) -> Result(Nil, Nil)

/// Gives back the #(column, row) count of the current terminal. This can be
/// called to get the initial size, and then updated when `Resize` events
/// come in.
@external(erlang, "glerm_ffi", "size")
pub fn size() -> Result(#(Int, Int), Nil)

/// Moves the cursor to the given location
@external(erlang, "glerm_ffi", "move_to")
pub fn move_to(column: Int, row: Int) -> Nil

/// Enables "raw mode" for the terminal. This will do a better job than I can
/// at explaining what all that entails:
///
///   https://docs.rs/crossterm/latest/crossterm/terminal/index.html#raw-mode
///
/// If you want to control the entire screen, capture all input events, and
/// place the cursor anywhere, this is what you want.
@external(erlang, "glerm_ffi", "enable_raw_mode")
pub fn enable_raw_mode() -> Result(Nil, Nil)

/// Turns off raw mode. This will disable the features described in
/// `enable_raw_mode`.
@external(erlang, "glerm_ffi", "disable_raw_mode")
pub fn disable_raw_mode() -> Result(Nil, Nil)

/// This will create a new terminal "window" that you can interact with. This
/// will preserve the user's existing terminal when exiting the program, or
/// calling `leave_alternate_screen`.
@external(erlang, "glerm_ffi", "enter_alternate_screen")
pub fn enter_alternate_screen() -> Result(Nil, Nil)

/// See:  `enter_alternate_screen`
@external(erlang, "glerm_ffi", "leave_alternate_screen")
pub fn leave_alternate_screen() -> Result(Nil, Nil)

/// This enables the capturing of mouse events. Without this, those event types
/// will not be emitted by the NIF.
@external(erlang, "glerm_ffi", "enable_mouse_capture")
pub fn enable_mouse_capture() -> Result(Nil, Nil)

/// This will stop the capture of mouse events in the terminal.
@external(erlang, "glerm_ffi", "disable_mouse_capture")
pub fn disable_mouse_capture() -> Result(Nil, Nil)

@external(erlang, "glerm_ffi", "cursor_position")
pub fn cursor_position() -> Result(#(Int, Int), Nil)

@external(erlang, "glerm_ffi", "clear_current_line")
pub fn clear_current_line() -> Result(Nil, Nil)

@external(erlang, "glerm_ffi", "hide_cursor")
pub fn hide_cursor() -> Result(Nil, Nil)

@external(erlang, "glerm_ffi", "show_cursor")
pub fn show_cursor() -> Result(Nil, Nil)

@external(erlang, "glerm_ffi", "move_cursor_left")
pub fn move_cursor_left(count: Int) -> Result(Nil, Nil)

@external(erlang, "glerm_ffi", "move_cursor_right")
pub fn move_cursor_right(count: Int) -> Result(Nil, Nil)

@external(erlang, "glerm_ffi", "move_to_column")
pub fn move_to_column(column: Int) -> Result(Nil, Nil)

pub type ListenerMessage(user_message) {
  Term(Event)
  User(user_message)
}

pub type ListenerSubject(user_message) =
  process.Subject(ListenerMessage(user_message))

pub type EventSubject =
  process.Subject(Event)

pub type ListenerSpec(state, user_message) {
  ListenerSpec(
    init: fn() -> #(state, Option(process.Selector(user_message))),
    loop: fn(ListenerMessage(user_message), state) ->
      actor.Next(ListenerMessage(user_message), state),
  )
}

/// This will start the NIF listener and set up the `Event` selector. The spec
/// argument allows for behavior during the initialization of the actor. That
/// function returns the initial state, and an optional user selector. This
/// allows this actor to also receive any user-defined messages.
pub fn start_listener_spec(
  init,
  loop: fn(state, ListenerMessage(a)) -> actor.Next(state, ListenerMessage(a)),
) {
  actor.new_with_initialiser(500, fn(_) {
    let pid = process.self()
    let #(state, user_selector) = init()
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
    process.spawn(fn() { listen(pid) })
    actor.initialised(state)
    |> actor.selecting(selector)
    |> Ok
  })
  |> actor.on_message(loop)
  |> actor.start
}

/// If you are not planning on sending custom messages to the terminal listener,
/// this method is the simplest. Give an initial state for the actor, and the
/// loop will receive only `Event`s and your provided state. To allow this
/// actor to receive additional user-defined messages, see `start_listener_spec`
pub fn start_listener(
  initial_state: state,
  loop: fn(state, Event) -> actor.Next(state, Event),
) -> actor.StartResult(Nil) {
  actor.new_with_initialiser(500, fn(_) {
    do_listen()
    actor.initialised(initial_state)
    |> actor.selecting(selector())
    |> Ok
  })
  |> actor.on_message(loop)
  |> actor.start
}

pub fn do_listen() {
  let pid = process.self()
  process.spawn(fn() { listen(pid) })
  selector()
}
