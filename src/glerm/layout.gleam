import gleam/list
import gleam/map.{Map}
import gleam/pair
import gleam/string
import glerm/screen.{Canvas, Position}
import shellout

pub type Orientation {
  Horizontal
  Vertical
}

pub type Dimension {
  Percent(Int)
  Pixels(Int)
}

pub type Color {
  White
}

pub type Overflow {
  Hidden
  Scroll
}

pub type BorderType {
  Square(Color)
  Rounded(Color)
}

pub type Style {
  Border(BorderType)
  Center
  Width(Dimension)
  Height(Dimension)
  Overflow
}

pub type Element {
  Box(children: List(Element), layout: Orientation, style: List(Style))
  Text(children: String)
}

pub fn horizontal_box(style: List(Style), children: List(Element)) -> Element {
  Box(children, Horizontal, style)
}

pub fn vertical_box(style: List(Style), children: List(Element)) -> Element {
  Box(children, Vertical, style)
}

pub fn text(children: String) -> Element {
  Text(children)
}

type BoundingBox {
  BoundingBox(top_left: Position, bottom_right: Position)
}

pub fn build(root: Element) -> Map(Position, String) {
  let bounding_box = screen.get_dimensions()
  do_build(root, BoundingBox(Position(0, 0), bounding_box), map.new())
}

fn do_build(
  element: Element,
  bounding_box: BoundingBox,
  canvas: Canvas,
) -> Canvas {
  let BoundingBox(top_left, bottom_right) = bounding_box
  case element {
    Box(children, Horizontal, _style) -> {
      let segment_lengths =
        { bottom_right.y - top_left.y } / list.length(children)
      list.index_fold(
        children,
        canvas,
        fn(canvas, child, index) {
          let y_offset = segment_lengths * index
          let area =
            BoundingBox(
              Position(top_left.x, top_left.y + y_offset),
              Position(bottom_right.x, bottom_right.y + y_offset),
            )
          do_build(child, area, canvas)
        },
      )
    }
    Box(children, Vertical, _style) -> {
      let segment_lengths =
        { bottom_right.x - top_left.x } / list.length(children)
      list.index_fold(
        children,
        canvas,
        fn(canvas, child, index) {
          let x_offset = segment_lengths * index
          let area =
            BoundingBox(
              Position(top_left.x + x_offset, top_left.y),
              Position(bottom_right.x + x_offset, bottom_right.y),
            )
          do_build(child, area, canvas)
        },
      )
    }
    Text(children) ->
      children
      |> string.to_graphemes
      |> list.fold(
        #(top_left, canvas),
        fn(state, char) {
          assert #(Position(row, column), canvas) = state
          let at_end_of_column = column + 1 >= bottom_right.y
          case at_end_of_column {
            True -> {
              let new_canvas = map.insert(canvas, Position(row + 1, 0), char)
              #(Position(row + 1, 1), new_canvas)
            }
            False -> {
              let new_canvas =
                map.insert(canvas, Position(row, column + 1), char)
              #(Position(row, column + 1), new_canvas)
            }
          }
        },
      )
      |> pair.second
  }
}

const rounded_top_left = ""

const rounded_top_right = ""

const rounded_bottom_left = ""

const rounded_bottom_right = ""

const square_top_left = ""

const square_top_right = ""

const square_bottom_left = ""

const square_bottom_right = ""

const vertical_border = ""

const horizontal_border = ""

fn add_border(
  canvas: Canvas,
  border: BorderType,
  bounding_box: BoundingBox,
) -> #(Canvas, BoundingBox) {
  let top_left = bounding_box.top_left
  let top_right = Position(bounding_box.top_left.x, bounding_box.bottom_right.y)
  let bottom_left =
    Position(bounding_box.bottom_right.x, bounding_box.top_left.y)
  let bottom_right = bounding_box.bottom_right

  let color_string = case border {
    Square(White) | Rounded(White) -> "white"
  }

  // concat [top_border, left_border, right_border, bottom_border] and the
  // corners and then update the canvas in a `list.fold`
  todo
}
