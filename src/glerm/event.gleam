import gleam/bit_string
import gleam/dynamic.{Dynamic}
import gleam/io

pub type EventType {
  KeyPress
  Resize
  Mouse
}

pub type Event {
  Key(key: String, control: Bool, alt: Bool, shift: Bool)
  Backspace
  Return
  ArrowUp
  ArrowDown
  ArrowLeft
  ArrowRight
  WindowResize
  Raw(event_type: EventType, char: Int, key: Int)
}

fn key(value: String) -> Event {
  Key(value, False, False, False)
}

fn control(event: Event) -> Event {
  case event {
    Key(key, _control, alt, shift) -> Key(key, True, alt, shift)
    _ -> event
  }
}

fn alt(event: Event) -> Event {
  case event {
    Key(key, control, _alt, shift) -> Key(key, control, True, shift)
    _ -> event
  }
}

fn shift(event: Event) -> Event {
  case event {
    Key(key, control, alt, _shift) -> Key(key, control, alt, True)
    _ -> event
  }
}

pub type RawEvent {
  RawEvent(event_type: EventType, char: Int, key: Int)
}

pub external fn decode(event: Dynamic) -> RawEvent =
  "Elixir.Glerm.Helpers" "convert_event"

pub fn convert(raw: RawEvent) -> Event {
  case raw {
    RawEvent(KeyPress, 0, 3) -> control(key("c"))
    RawEvent(KeyPress, char, 0) -> {
      assert Ok(char) = bit_string.to_string(<<char>>)
      key(char)
    }
    RawEvent(KeyPress, 0, 16) -> control(key("p"))
    RawEvent(KeyPress, 0, 14) -> control(key("n"))
    RawEvent(KeyPress, 0, 32) -> key(" ")
    RawEvent(KeyPress, 0, 127) -> Backspace
    RawEvent(KeyPress, 0, 13) -> Return
    RawEvent(KeyPress, 0, 65517) -> ArrowUp
    RawEvent(KeyPress, 0, 65516) -> ArrowDown
    RawEvent(KeyPress, 0, 65515) -> ArrowLeft
    RawEvent(KeyPress, 0, 65514) -> ArrowRight
    RawEvent(Resize, _, _) -> WindowResize
    RawEvent(KeyPress, char, key) -> Raw(KeyPress, char, key)
    RawEvent(Mouse, char, key) -> Raw(Mouse, char, key)
  }
}
