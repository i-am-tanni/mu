defmodule Mu.Character.LookView do
  use Kalevala.Character.View

  def render("look", %{room: room}) do
    ~E"""
    <%= room.name %>
    Exits: [<%= exits(room.exits) %>]
    """
  end

  defp exits(exits) do
    exits
    |> Enum.map(& &1.exit_name)
    |> View.join(", ")
  end
end
