import gleam/iterator
import gleam/list
import gleam/map
import gleam/string
import glerm/screen.{Canvas, Cell, Position}

pub type Orientation {
  Horizontal
  Vertical
}

pub type Dimension {
  Percent(Int)
  Pixels(Int)
}

pub type Overflow {
  Hidden
  Scroll
}

pub type BorderType {
  Square(String)
  Rounded(String)
}

pub type Style {
  Border(BorderType)
  Padding(Int)
}

// Center
// Width(Dimension)
// Height(Dimension)
// Overflow

pub type Element {
  Box(children: List(Element), layout: Orientation, style: List(Style))
  Text(children: String, style: List(Style))
}

pub fn horizontal_box(style: List(Style), children: List(Element)) -> Element {
  Box(children, Horizontal, style)
}

pub fn vertical_box(style: List(Style), children: List(Element)) -> Element {
  Box(children, Vertical, style)
}

pub fn text(style: List(Style), children: String) -> Element {
  Text(children, style)
}

type BoundingBox {
  BoundingBox(top_left: Position, bottom_right: Position)
}

pub fn build(root: Element) -> Canvas {
  let bounding_box = screen.get_dimensions()
  // io.debug(#("bounding box is", bounding_box))
  do_build(root, BoundingBox(Position(0, 0), bounding_box), map.new())
}

fn do_build(
  element: Element,
  bounding_box: BoundingBox,
  canvas: Canvas,
) -> Canvas {
  case element {
    Box(children, Horizontal, styles) -> {
      let #(canvas, BoundingBox(top_left, bottom_right)) =
        apply_style(canvas, styles, bounding_box)
      let segment_lengths =
        { bottom_right.y - top_left.y } / list.length(children)
      list.index_fold(
        children,
        canvas,
        fn(canvas, child, index) {
          let y_offset = segment_lengths * index
          let bottom_y = case index == list.length(children) - 1 {
            True -> top_left.y + y_offset + segment_lengths
            False -> top_left.y + y_offset + segment_lengths - 1
          }
          let area =
            BoundingBox(
              Position(top_left.x, top_left.y + y_offset),
              Position(bottom_right.x, bottom_y),
            )
          // io.debug(#("child at", index, "for horizontal is", area))
          do_build(child, area, canvas)
        },
      )
    }
    Box(children, Vertical, styles) -> {
      let #(canvas, BoundingBox(top_left, bottom_right)) =
        apply_style(canvas, styles, bounding_box)
      let segment_lengths =
        { bottom_right.x - top_left.x } / list.length(children)
      list.index_fold(
        children,
        canvas,
        fn(canvas, child, index) {
          let x_offset = segment_lengths * index
          let bottom_x = case index == list.length(children) - 1 {
            True -> top_left.x + x_offset + segment_lengths
            False -> top_left.x + x_offset + segment_lengths - 1
          }
          let area =
            BoundingBox(
              Position(top_left.x + x_offset, top_left.y),
              Position(bottom_x, bottom_right.y),
            )
          // io.debug(#("child at", index, "for vertical is", area))
          do_build(child, area, canvas)
        },
      )
    }
    Text(children, style) -> {
      let #(canvas, bounding_box) = apply_style(canvas, style, bounding_box)
      let line_length = bounding_box.bottom_right.y - bounding_box.top_left.y
      let lines =
        children
        |> string.split(on: " ")
        |> list.fold(
          #([], ""),
          fn(state, word) {
            assert #(lines, current_line) = state
            let with_new_word = case current_line {
              "" -> word
              current -> current <> " " <> word
            }
            case string.length(with_new_word) > line_length {
              True -> #(
                list.append(
                  lines,
                  [string.pad_right(current_line, line_length, " ")],
                ),
                word,
              )
              False -> #(lines, with_new_word)
            }
          },
        )
        |> fn(pair) {
          assert #(lines, word) = pair
          case word {
            "" -> lines
            word -> list.append(lines, [word])
          }
        }
      list.index_fold(
        lines,
        canvas,
        fn(canvas, line, row) {
          line
          |> string.to_graphemes
          |> list.index_map(fn(column, char) {
            #(
              Position(
                bounding_box.top_left.x + row,
                bounding_box.top_left.y + column,
              ),
              Cell(char, "white"),
            )
          })
          |> map.from_list
          |> map.merge(canvas, _)
        },
      )
    }
  }
}

const rounded_top_left = "╭"

const rounded_top_right = "╮"

const rounded_bottom_left = "╰"

const rounded_bottom_right = "╯"

const square_top_left = "┌"

const square_top_right = "┐"

const square_bottom_left = "└"

const square_bottom_right = "┘"

const vertical_border = "│"

const horizontal_border = "─"

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
    Square(color) | Rounded(color) -> color
  }

  let top_border =
    iterator.range(top_left.y, top_right.y)
    |> iterator.map(fn(y) {
      #(Position(top_left.x, y), Cell(horizontal_border, color_string))
    })

  let right_border =
    iterator.range(top_right.x, bottom_right.x)
    |> iterator.map(fn(x) {
      #(Position(x, top_right.y), Cell(vertical_border, color_string))
    })

  let bottom_border =
    iterator.range(bottom_left.y, bottom_right.y)
    |> iterator.map(fn(y) {
      #(Position(bottom_left.x, y), Cell(horizontal_border, color_string))
    })

  let left_border =
    iterator.range(top_left.x, bottom_left.x)
    |> iterator.map(fn(x) {
      #(Position(x, top_left.y), Cell(vertical_border, color_string))
    })

  let corners = case border {
    Square(_color) -> [
      #(top_left, Cell(square_top_left, color_string)),
      #(top_right, Cell(square_top_right, color_string)),
      #(bottom_right, Cell(square_bottom_right, color_string)),
      #(bottom_left, Cell(square_bottom_left, color_string)),
    ]
    Rounded(_color) -> [
      #(top_left, Cell(rounded_top_left, color_string)),
      #(top_right, Cell(rounded_top_right, color_string)),
      #(bottom_right, Cell(rounded_bottom_right, color_string)),
      #(bottom_left, Cell(rounded_bottom_left, color_string)),
    ]
  }

  let borders =
    top_border
    |> iterator.append(right_border)
    |> iterator.append(bottom_border)
    |> iterator.append(left_border)
    |> iterator.to_list
    |> list.append(corners)
    |> map.from_list

  let updated_canvas = map.merge(canvas, borders)
  #(
    updated_canvas,
    BoundingBox(
      Position(top_left.x + 1, top_left.y + 1),
      Position(bottom_right.x - 1, bottom_right.y - 1),
    ),
  )
}

fn add_padding(
  canvas: Canvas,
  amount: Int,
  bounding_box: BoundingBox,
) -> #(Canvas, BoundingBox) {
  #(
    canvas,
    BoundingBox(
      Position(
        bounding_box.top_left.x + amount,
        bounding_box.top_left.y + amount,
      ),
      Position(
        bounding_box.bottom_right.x - amount,
        bounding_box.bottom_right.y - amount,
      ),
    ),
  )
}

fn apply_style(
  canvas: Canvas,
  styles: List(Style),
  bounding_box: BoundingBox,
) -> #(Canvas, BoundingBox) {
  list.fold(
    styles,
    #(canvas, bounding_box),
    fn(state, style) {
      assert #(canvas, bounding_box) = state
      case style {
        Border(border_type) -> add_border(canvas, border_type, bounding_box)
        Padding(amount) -> add_padding(canvas, amount, bounding_box)
      }
    },
  )
}
