defmodule Mu.Character.BuildCommand do
  @moduledoc """
  Commands for building areas.
  """
  use Kalevala.Character.Command

  @valid_exit_names ~w(north south east west up down)

  @doc """
  Sends the room a request to dig an exit from the current room
  """
  def dig(conn, params) do
    start_exit_name = to_long(params["start_exit_name"])

    end_exit_name =
      case params["end_exit_name"] do
        nil -> opposite(start_exit_name)
        exit_name -> to_long(exit_name)
      end

    cond do
      start_exit_name not in @valid_exit_names ->
        conn
        |> assign(:prompt, true)
        |> assign(:exit_name, start_exit_name)
        |> render(BuildView, "invalid-exit-name")

      end_exit_name not in @valid_exit_names ->
        conn
        |> assign(:prompt, true)
        |> assign(:exit_name, end_exit_name)
        |> render(BuildView, "invalid-exit-name")

      true ->
        params = %{
          start_exit_name: start_exit_name,
          end_exit_name: end_exit_name,
          room_id: params["new_room_id"]
        }

        conn
        |> event("room/dig", params)
        |> assign(:prompt, false)
    end
  end

  defp to_long(exit_name) do
    case exit_name do
      "n" -> "north"
      "s" -> "south"
      "e" -> "east"
      "w" -> "west"
      "u" -> "up"
      "d" -> "down"
      _ -> exit_name
    end
  end

  defp opposite(exit_name) do
    case exit_name do
      "north" -> "south"
      "south" -> "north"
      "east" -> "west"
      "west" -> "east"
      "up" -> "down"
      "down" -> "up"
      _ -> nil
    end
  end
end
