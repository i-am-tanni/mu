defmodule Mu.Character.MoveCommand do
  use Kalevala.Character.Command

  def run(conn, params) do
    direction = params["command"]

    conn
    |> request_movement(to_long(direction))
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
