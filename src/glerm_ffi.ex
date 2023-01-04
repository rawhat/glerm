defmodule Glerm.Helpers do
  alias ExTermbox.Cell
  alias ExTermbox.Position
  alias ExTermbox.Bindings, as: Termbox
  alias ExTermbox.Event
  alias ExTermbox.Constants

  def get_cell(x, y, ch, foreground, background) do
    %Cell{
      position: %Position{x: x, y: y},
      ch: ch,
      fg: Constants.color(foreground),
      bg: Constants.color(background)
    }
  end

  def write_charlist(col, row, charlist, foreground, background) do
    for {ch, x} <- Enum.with_index(charlist) do
      Termbox.put_cell(get_cell(col + x, row, ch, foreground, background))
    end
  end

  def write_character(col, row, char, color, bg) do
    Termbox.put_cell(get_cell(col, row, char, color, bg))
  end

  def convert_event({:event, %Event{type: type, ch: ch, key: key} = raw}) do
    case type do
      1 -> {:raw_event, :key_press, ch, key}
      2 -> {:raw_event, :resize, ch, key}
      3 -> {:raw_event, :mouse, ch, key}
    end
  end

  def char_code_to_string(code) do
    :erlang.binary_to_list(<<code>>)
  end
end
