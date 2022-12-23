defmodule Glerm.Helpers do
  alias ExTermbox.Cell
  alias ExTermbox.Position
  alias ExTermbox.Bindings, as: Termbox
  alias ExTermbox.Event

  def get_cell(x, y, ch) do
    %Cell{position: %Position{x: x, y: y}, ch: ch}
  end

  def write_charlist(row, col, charlist) do
    for {ch, x} <- Enum.with_index(charlist) do
      Termbox.put_cell(get_cell(col + x, row, ch))
    end
  end

  def write_character(row, col, char) do
    Termbox.put_cell(get_cell(col, row, char))
  end

  def convert_event({:event, %Event{ch: ch, key: key}}) do
    {:event, ch, key}
  end

  def char_code_to_string(code) do
    :erlang.binary_to_list(<<code>>)
  end
end
