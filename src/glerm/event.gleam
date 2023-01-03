import gleam/bit_string
import gleam/dynamic.{Dynamic}
import gleam/io

pub type Event {
  Key(key: String, control: Bool, alt: Bool, shift: Bool)
  Backspace
  Return
  ArrowUp
  ArrowDown
  ArrowLeft
  ArrowRight
  Raw(char: Int, key: Int)
}

fn key(value: String) -> Event {
  Key(value, False, False, False)
}

fn ctrl(event: Event) -> Event {
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
  RawEvent(char: Int, key: Int)
}

pub external fn decode(event: Dynamic) -> RawEvent =
  "Elixir.Glerm.Helpers" "convert_event"

pub fn convert(raw: RawEvent) -> Event {
  // io.debug(#("converting", raw))
  case raw {
    RawEvent(0, 3) -> ctrl(key("c"))
    RawEvent(char, 0) -> {
      assert Ok(char) = bit_string.to_string(<<char>>)
      key(char)
    }
    RawEvent(0, 32) -> key(" ")
    RawEvent(0, 127) -> Backspace
    RawEvent(0, 13) -> Return
    RawEvent(0, 65517) -> ArrowUp
    RawEvent(0, 65516) -> ArrowDown
    RawEvent(0, 65515) -> ArrowLeft
    RawEvent(0, 65514) -> ArrowRight
    RawEvent(char, key) -> Raw(char, key)
  }
}
