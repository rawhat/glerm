import gleam/io

external fn hello() -> String =
  "glerm_ffi" "hello"

pub fn main() {
  hello()
  |> io.println
}
