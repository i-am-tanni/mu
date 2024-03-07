defmodule Mu.Character.MoveCommand do
  use Kalevala.Character.Command

  alias Mu.Character.Action
  alias Mu.Character.MoveAction

  def run(conn, params) do
    direction = to_long(params["command"])
    action = MoveAction.build(%{direction: direction})

    conn
    |> Action.put(action)
    |> assign(:prompt, false)
  end

  defp to_long(direction) do
    case String.length(direction) < 3 do
      true ->
        case direction do
          "n" -> "north"
          "s" -> "south"
          "e" -> "east"
          "w" -> "west"
          _ -> direction
        end

      false ->
        direction
    end
  end
end
