defmodule Mu.Character.WriteView do
  use Kalevala.Character.View

  def render("topic", %{topic: topic}) do
    ~i(Editing #{topic})
  end

  def render("buffer", %{buffer: buffer}) do
    {buffer, _} =
      Enum.map_reduce(buffer, 0, fn line, i ->
        line_count = String.pad_leading(Integer.to_string(i), 2)
        {~i(#{line_count}: #{line}\r\n), i + 1}
      end)

    buffer
  end

  def render("write-instructions", _) do
    ~i(Write Mode. Prepend any line with '~' to exit.)
  end

  def render("edit-instructions", _) do
    ~E"""
    Edit Mode Commands:
    :q - quit    :wq - save and quit  :c - cancel
    :w - save    :l - load            :p - print
    :[min,max]d  - delete. If no index or range provided, deletes the last line.
    :[index]i    - insert. If no index provided, appends.
    :[min,max]s/pattern/replacement - find and replace
    """
  end

  def render("max-lines-reached", _) do
    ~i(Error: Maximum line threshold reached.)
  end

  def render("saved", _) do
    ~i(Stashed! Feel free to edit or quit.)
  end

  def render("invalid-command", _) do
    ~i(Invalid commmand received.)
  end
end
