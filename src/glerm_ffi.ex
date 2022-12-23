defmodule Glerm.Helpers do
  alias ExTermbox.Cell
  alias ExTermbox.Position
  alias ExTermbox.Bindings, as: Termbox
  alias ExTermbox.Event
  alias ExTermbox.Constants

  def get_cell(x, y, ch, color) do
    %Cell{position: %Position{x: x, y: y}, ch: ch, fg: Constants.color(color)}
  end

  def write_charlist(row, col, charlist, color) do
    for {ch, x} <- Enum.with_index(charlist) do
      Termbox.put_cell(get_cell(col + x, row, ch, color))
    end
  end

  def write_character(row, col, char, color) do
    Termbox.put_cell(get_cell(col, row, char, color))
  end

  def convert_event({:event, %Event{ch: ch, key: key}}) do
    {:event, ch, key}
  end

  def char_code_to_string(code) do
    :erlang.binary_to_list(<<code>>)
  end
end
