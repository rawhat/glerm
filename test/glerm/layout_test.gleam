import gleam/map
import gleeunit/should
import glerm/layout.{
  Border, BoundingBox, Rounded, border, do_build, horizontal_box, style, text,
  vertical_box,
}
import gleam/string
import glerm/screen.{Cell, Position}
import gleam/io
import gleam_community/ansi

// pub fn render_text_test() {
//   let bounding_box = BoundingBox(Position(0, 0), Position(5, 0))
//   style()
//   |> text("hi mom")
//   |> do_build(bounding_box, map.new())
//   |> layout.to_string(bounding_box, _)
//   |> should.equal("hi mom")
// }

pub fn render_horizontal_box_test() {
  let bounding_box = BoundingBox(Position(0, 0), Position(7, 2))
  let str =
    horizontal_box(
      style()
      |> border(Rounded(ansi.white)),
      [text(style(), "hi"), text(style(), "mom")],
    )
    |> do_build(bounding_box, map.new())
    |> layout.to_string(bounding_box, _)
    |> io.debug

  str
  |> should.equal(string.trim(
    "
╭──────╮
│hi mom│
╰──────╯
  ",
  ))
}

pub fn render_vertical_box_test() {
  let bounding_box = BoundingBox(Position(0, 0), Position(4, 3))
  let str =
    vertical_box(
      style()
      |> border(Rounded(ansi.white)),
      [text(style(), "hi"), text(style(), "mom")],
    )
    |> do_build(bounding_box, map.new())
    |> layout.to_string(bounding_box, _)
    |> io.debug

  str
  |> should.equal(string.trim(
    "
╭───╮
│hi │
│mom│
╰───╯
  ",
  ))
}
