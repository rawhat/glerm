import gleam/dynamic.{Dynamic}
import gleam/option.{Option}

pub type Modifier {
  Shift
  Alt
  Control
}

pub type KeyCode {
  Character(String)
  Left
  Right
  Down
  Up
  Backspace
  Unsupported
}

pub type Resize {
  Resize(Int, Int)
}

pub type Event {
  Key(key: KeyCode, modifier: Option(Modifier))
}

// TODO:  ewww? maybe?
pub fn decode(message: Dynamic) -> Event {
  dynamic.unsafe_coerce(message)
}
