import gleam/int
import gleam/io
import gleam/iterator
import gleam/list
import gleam/float
import gleam/function
import gleam/map
import gleam/option.{None, Option, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/result
import gleam/string
import gleam/string_builder
import glerm/screen.{AnsiStyle, Canvas, Cell, Position}
import gleam_community/ansi

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

pub type Border {
  Square(AnsiStyle)
  Rounded(AnsiStyle)
}

pub type LineBreak {
  Character
  Word
}

pub type Style {
  Style(
    text: Option(AnsiStyle),
    border: Option(Border),
    padding: Option(Int),
    width: Option(Dimension),
    height: Option(Dimension),
    overflow: Option(Overflow),
    line_break: Option(LineBreak),
  )
}

pub fn style() -> Style {
  Style(
    text: None,
    border: None,
    padding: None,
    width: None,
    height: None,
    overflow: None,
    line_break: None,
  )
}

pub fn border(style: Style, border: Border) -> Style {
  Style(..style, border: Some(border))
}

pub fn padding(style: Style, padding: Int) -> Style {
  Style(..style, padding: Some(padding))
}

pub fn width(style: Style, width: Dimension) -> Style {
  Style(..style, width: Some(width))
}

pub fn height(style: Style, height: Dimension) -> Style {
  Style(..style, height: Some(height))
}

pub fn overflow(style: Style, overflow: Overflow) -> Style {
  Style(..style, overflow: Some(overflow))
}

pub fn line_break(style: Style, line_break: LineBreak) -> Style {
  Style(..style, line_break: Some(line_break))
}

pub fn text_style(style: Style, ansi_style: AnsiStyle) -> Style {
  Style(..style, text: Some(ansi_style))
}

// Center
// Overflow

pub type Element {
  Box(children: List(Element), layout: Orientation, style: Style)
  Text(children: String, style: Style)
  Row(children: String, style: Style)
}

pub fn horizontal_box(style: Style, children: List(Element)) -> Element {
  Box(children, Horizontal, style)
}

pub fn vertical_box(style: Style, children: List(Element)) -> Element {
  Box(children, Vertical, style)
}

pub fn text(style: Style, children: String) -> Element {
  Text(children, style)
}

pub fn row(style: Style, children: String) -> Element {
  Row(children, style)
}

pub type BoundingBox {
  BoundingBox(top_left: Position, bottom_right: Position)
}

pub fn build(root: Element) -> Canvas {
  let bounding_box = screen.get_dimensions()
  do_build(root, BoundingBox(Position(0, 0), bounding_box), map.new())
}

pub fn do_build(
  element: Element,
  bounding_box: BoundingBox,
  canvas: Canvas,
) -> Canvas {
  case element {
    Box(children, Horizontal, styles) -> {
      let #(canvas, BoundingBox(top_left, bottom_right)) =
        apply_style(canvas, styles, bounding_box)
      let total_width = bottom_right.column - top_left.column
      let #(fixed, fill) =
        children
        |> list.index_map(fn(index, child) {
          let fixed = case child {
            Box(style: style, ..) -> option.to_result(style.width, Nil)
            Text(style: style, ..) -> option.to_result(style.width, Nil)
            _ -> Error(Nil)
          }
          #(index, fixed)
        })
        |> list.partition(fn(pair) {
          let #(_index, fixed) = pair
          result.is_ok(fixed)
        })
      let #(widths, remaining_width) =
        list.fold(
          fixed,
          #(map.new(), total_width - 1),
          fn(state, entry) {
            let #(widths, remaining) = state
            let assert #(index, Ok(width)) = entry
            case width {
              Percent(amount) -> {
                let size = percentage(remaining, amount)
                #(map.insert(widths, index, size), int.max(remaining - size, 0))
              }
              Pixels(amount) -> #(
                map.insert(widths, index, int.min(remaining, amount)),
                int.max(remaining - amount, 0),
              )
            }
          },
        )
      let extras = remaining_width % list.length(fill)
      let extra_widths =
        list.repeat(1, extras)
        |> list.append(list.repeat(0, list.length(fill) - extras))
      let child_widths =
        fill
        |> list.zip(extra_widths)
        |> list.fold(
          widths,
          fn(widths, child_with_extra) {
            let #(#(index, _), extra) = child_with_extra
            map.insert(
              widths,
              index,
              remaining_width / list.length(fill) + extra,
            )
          },
        )
      child_widths
      |> map.to_list
      |> list.sort(fn(a, b) {
        let #(a_index, _) = a
        let #(b_index, _) = b
        int.compare(a_index, b_index)
      })
      |> list.zip(children)
      |> list.fold(
        #(canvas, top_left.column),
        fn(canvas, pair) {
          let #(canvas, col_offset) = canvas
          let #(#(index, width), child) = pair
          let end = case index == list.length(children) - 1 {
            True -> col_offset + width
            False -> col_offset + width - 1
          }
          let area =
            BoundingBox(
              Position(col_offset, top_left.row),
              Position(end, bottom_right.row),
            )
          // Since we are using the height to determine the size in the box, we
          // don't want to apply it a second time. To do that, we can trim this
          // property out of the style
          let child = case child {
            Box(style: style, children: children, layout: layout) ->
              Box(
                children: children,
                style: Style(..style, width: None),
                layout: layout,
              )
            Text(style: style, children: children) ->
              Text(children: children, style: Style(..style, width: None))
            child -> child
          }
          let new_canvas = do_build(child, area, canvas)
          #(new_canvas, col_offset + width)
        },
      )
      |> fn(pair) {
        let #(canvas, _) = pair
        canvas
      }
    }
    Box(children, Vertical, styles) -> {
      let #(canvas, BoundingBox(top_left, bottom_right)) =
        apply_style(canvas, styles, bounding_box)
      let total_height = bottom_right.row - top_left.row
      let #(fixed, fill) =
        children
        |> list.index_map(fn(index, child) {
          let fixed = case child {
            Box(style: style, ..) -> option.to_result(style.height, Nil)
            Text(style: style, ..) -> option.to_result(style.height, Nil)
            Row(..) -> Ok(Pixels(1))
          }
          #(index, fixed)
        })
        |> list.partition(fn(pair) {
          let #(_index, fixed) = pair
          result.is_ok(fixed)
        })
      let #(heights, remaining_height) =
        list.fold(
          fixed,
          #(map.new(), total_height),
          fn(state, entry) {
            let #(heights, remaining) = state
            let assert #(index, Ok(height)) = entry
            case height {
              Percent(amount) -> {
                let size = percentage(remaining, amount)
                #(
                  map.insert(heights, index, size),
                  int.max(remaining - size, 0),
                )
              }
              Pixels(amount) -> #(
                map.insert(heights, index, int.min(remaining, amount)),
                int.max(remaining - amount, 0),
              )
            }
          },
        )
      let extras = remaining_height % list.length(fill)
      let extra_heights =
        list.repeat(1, extras)
        |> list.append(list.repeat(0, list.length(fill) - extras))
      let child_heights =
        fill
        |> list.zip(extra_heights)
        |> list.fold(
          heights,
          fn(heights, child_with_extra) {
            let #(#(index, _), extra) = child_with_extra
            map.insert(
              heights,
              index,
              remaining_height / list.length(fill) + extra,
            )
          },
        )
      child_heights
      |> map.to_list
      |> list.sort(fn(a, b) {
        let #(a_index, _) = a
        let #(b_index, _) = b
        int.compare(a_index, b_index)
      })
      |> list.zip(children)
      |> list.fold(
        #(canvas, top_left.row),
        fn(canvas, pair) {
          let #(canvas, row_offset) = canvas
          let #(#(index, height), child) = pair
          let end = case index == list.length(children) - 1 {
            True -> row_offset + height
            False -> row_offset + height - 1
          }
          let area =
            BoundingBox(
              Position(top_left.column, row_offset),
              Position(bottom_right.column, end),
            )
          // Since we are using the height to determine the size in the box, we
          // don't want to apply it a second time. To do that, we can trim this
          // property out of the style
          let child = case child {
            Box(style: style, children: children, layout: layout) ->
              Box(
                children: children,
                style: Style(..style, height: None),
                layout: layout,
              )
            Text(style: style, children: children) ->
              Text(children: children, style: Style(..style, height: None))
            child -> child
          }
          let new_canvas = do_build(child, area, canvas)
          #(new_canvas, int.min(row_offset + height, bottom_right.row))
        },
      )
      |> fn(pair) {
        let #(canvas, _) = pair
        canvas
      }
    }
    Text(children, style) -> {
      let #(canvas, bounding_box) = apply_style(canvas, style, bounding_box)
      let height =
        int.max(bounding_box.bottom_right.row - bounding_box.top_left.row, 1)
      // Bounding box is inclusive, so we need to add one here
      let line_length =
        bounding_box.bottom_right.column - bounding_box.top_left.column + 1
      case style.line_break {
        Some(Character) | None ->
          children
          |> string.to_graphemes
          |> list.sized_chunk(line_length)
          |> list.take(height)
          |> list.index_map(fn(row, line) {
            list.index_map(
              line,
              fn(col, char) {
                #(
                  Position(
                    bounding_box.top_left.column + col,
                    bounding_box.top_left.row + row,
                  ),
                  Cell(char, option.unwrap(style.text, function.identity)),
                )
              },
            )
          })
          |> list.flatten
          |> map.from_list
          |> map.merge(canvas, _)
        Some(Word) ->
          children
          |> string.split(on: " ")
          |> list.fold(
            [],
            fn(lines, word) {
              case lines {
                [] -> [word]
                [line, ..rest] ->
                  case string.length(line <> " " <> word) {
                    n if n > line_length -> [word, ..lines]
                    _ -> [line <> " " <> word, ..rest]
                  }
              }
            },
          )
          |> list.reverse
          |> list.take(height)
          |> list.index_map(fn(row, line) {
            line
            |> string.to_graphemes
            |> list.index_map(fn(col, char) {
              #(
                Position(
                  bounding_box.top_left.column + col,
                  bounding_box.top_left.row + row,
                ),
                Cell(char, option.unwrap(style.text, function.identity)),
              )
            })
          })
          |> list.flatten
          |> map.from_list
          |> map.merge(canvas, _)
      }
    }
    Row(children, style) -> {
      let #(canvas, bounding_box) = apply_style(canvas, style, bounding_box)
      let line_length =
        bounding_box.bottom_right.column - bounding_box.top_left.column
      children
      |> string.to_graphemes
      |> list.take(line_length)
      |> list.index_fold(
        canvas,
        fn(canvas, char, col) {
          map.insert(
            canvas,
            Position(
              bounding_box.top_left.column + col,
              bounding_box.top_left.row,
            ),
            Cell(char, option.unwrap(style.text, function.identity)),
          )
        },
      )
    }
  }
}

pub const rounded_top_left = "╭"

pub const rounded_top_right = "╮"

pub const rounded_bottom_left = "╰"

pub const rounded_bottom_right = "╯"

pub const square_top_left = "┌"

pub const square_top_right = "┐"

pub const square_bottom_left = "└"

pub const square_bottom_right = "┘"

pub const vertical_border = "│"

pub const horizontal_border = "─"

fn add_border(
  canvas: Canvas,
  border: Border,
  bounding_box: BoundingBox,
) -> #(Canvas, BoundingBox) {
  let top_left = bounding_box.top_left
  let top_right =
    Position(bounding_box.bottom_right.column, bounding_box.top_left.row)
  let bottom_left =
    Position(bounding_box.top_left.column, bounding_box.bottom_right.row)
  let bottom_right = bounding_box.bottom_right

  let style = case border {
    Square(style) | Rounded(style) -> style
  }

  let top_border =
    iterator.range(top_left.column, top_right.column)
    |> iterator.map(fn(column) {
      #(Position(column, top_left.row), Cell(horizontal_border, style))
    })

  let right_border =
    iterator.range(top_right.row, bottom_right.row)
    |> iterator.map(fn(row) {
      #(Position(top_right.column, row), Cell(vertical_border, style))
    })

  let bottom_border =
    iterator.range(bottom_left.column, bottom_right.column)
    |> iterator.map(fn(column) {
      #(Position(column, bottom_left.row), Cell(horizontal_border, style))
    })

  let left_border =
    iterator.range(top_left.row, bottom_left.row)
    |> iterator.map(fn(row) {
      #(Position(top_left.column, row), Cell(vertical_border, style))
    })

  let corners = case border {
    Square(_color) -> [
      #(top_left, Cell(square_top_left, style)),
      #(top_right, Cell(square_top_right, style)),
      #(bottom_right, Cell(square_bottom_right, style)),
      #(bottom_left, Cell(square_bottom_left, style)),
    ]
    Rounded(_color) -> [
      #(top_left, Cell(rounded_top_left, style)),
      #(top_right, Cell(rounded_top_right, style)),
      #(bottom_right, Cell(rounded_bottom_right, style)),
      #(bottom_left, Cell(rounded_bottom_left, style)),
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
      Position(top_left.column + 1, top_left.row + 1),
      Position(bottom_right.column - 1, bottom_right.row - 1),
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
        bounding_box.top_left.column + amount,
        bounding_box.top_left.row + amount,
      ),
      Position(
        bounding_box.bottom_right.column - amount,
        bounding_box.bottom_right.row - amount,
      ),
    ),
  )
}

// TODO:  this will need to be handled in the `*Box` components as well
fn set_width(
  canvas: Canvas,
  width: Dimension,
  bounding_box: BoundingBox,
) -> #(Canvas, BoundingBox) {
  case width {
    Percent(amount) -> {
      let new_column =
        float.round(
          int.to_float(
            bounding_box.bottom_right.column - bounding_box.top_left.column,
          ) *. { int.to_float(amount) /. 100.0 },
        )
      #(
        canvas,
        BoundingBox(
          bounding_box.top_left,
          Position(..bounding_box.bottom_right, column: new_column),
        ),
      )
    }
    Pixels(amount) -> #(
      canvas,
      BoundingBox(
        bounding_box.top_left,
        Position(
          ..bounding_box.bottom_right,
          column: bounding_box.top_left.column + amount,
        ),
      ),
    )
  }
}

// TODO:  this will need to be handled in the `*Box` components as well
fn set_height(
  canvas: Canvas,
  height: Dimension,
  bounding_box: BoundingBox,
) -> #(Canvas, BoundingBox) {
  case height {
    Percent(amount) -> {
      let new_row =
        float.round(
          int.to_float(
            bounding_box.bottom_right.row - bounding_box.top_left.row,
          ) *. { int.to_float(amount) /. 100.0 },
        )
      #(
        canvas,
        BoundingBox(
          bounding_box.top_left,
          Position(..bounding_box.bottom_right, row: new_row),
        ),
      )
    }
    Pixels(amount) -> #(
      canvas,
      BoundingBox(
        bounding_box.top_left,
        Position(
          ..bounding_box.bottom_right,
          row: bounding_box.top_left.row + amount,
        ),
      ),
    )
  }
}

fn apply_style(
  canvas: Canvas,
  style: Style,
  bounding_box: BoundingBox,
) -> #(Canvas, BoundingBox) {
  let #(canvas, bounding_box) =
    style.width
    |> option.map(set_width(canvas, _, bounding_box))
    |> option.unwrap(#(canvas, bounding_box))
  let #(canvas, bounding_box) =
    style.height
    |> option.map(set_height(canvas, _, bounding_box))
    |> option.unwrap(#(canvas, bounding_box))
  let #(canvas, bounding_box) =
    style.border
    |> option.map(add_border(canvas, _, bounding_box))
    |> option.unwrap(#(canvas, bounding_box))
  let #(canvas, bounding_box) =
    style.padding
    |> option.map(add_padding(canvas, _, bounding_box))
    |> option.unwrap(#(canvas, bounding_box))

  #(canvas, bounding_box)
}

fn percentage(amount: Int, percent: Int) -> Int {
  float.round(int.to_float(amount) *. { int.to_float(percent) /. 100.0 })
}

pub fn to_string(bounding_box: BoundingBox, canvas: Canvas) -> String {
  let rows =
    iterator.range(bounding_box.top_left.row, bounding_box.bottom_right.row)
  let columns =
    iterator.range(
      bounding_box.top_left.column,
      bounding_box.bottom_right.column,
    )

  rows
  |> iterator.flat_map(fn(row) {
    iterator.map(columns, fn(col) { Position(col, row) })
  })
  |> iterator.fold(
    string_builder.new(),
    fn(str, pos) {
      let value =
        canvas
        |> map.get(pos)
        |> result.map(fn(cell) { cell.value })
        |> result.unwrap(" ")

      case pos.column, pos.row {
        0, row if row > 0 -> string_builder.append(str, "\n" <> value)
        _, _ -> string_builder.append(str, value)
      }
    },
  )
  |> string_builder.to_string
}
