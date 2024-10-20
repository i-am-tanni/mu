defmodule Mu.Character.BrainView do
  use Kalevala.Character.View

  @max_items 20

  # Renders a behavioral tree list to a printable IO list
  def render("list", %{list: list} = assigns) do
    start = Map.get(assigns, :start, 0)
    lines = Map.get(assigns, :lines, @max_lines)

    with list = [_ | _] <- Enum.slice(list, start, @max_items) do
      %{level: level_offset} = Enum.min_by(list, & &1.level)

      {view, _} =
        Enum.map_reduce(list, start, fn node, index ->
          {render_node(node, index, level_offset), index + 1}
        end)

      view
    end
  end

  # map -> integer -> integer -> iolist
  defp render_node(node, index, level_offset) do
    index =
      index
      |> Integer.to_string()
      |> String.pad_leading(3, "0")

    level = node.level - level_offset

    indents =
      case level > 0 do
        true -> Enum.map(1..level, fn _ -> "|    " end)
        false -> ""
      end

    ~i(#{index}: #{indents}#{node.text}\r\n)
  end
end
