defmodule Mu.Character.BuildCommand do
  @moduledoc """
  Commands for building areas.
  """
  use Kalevala.Character.Command
  alias Mu.Character.BuildView

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

  def set(conn, %{"type" => "room"} = params), do: set_room(conn, params)

  defp set_room(conn, params) do
    key = params["key"]

    case maybe(to_room_key(key)) do
      {:ok, key} ->
        val = params["val"]
        val =
          if key in [:x, :y, :z],
          do: String.to_integer(val),
        else: val

        params = %{key: key, val: val}

        conn
        |> event("room/set", params)
        |> assign(:prompt, false)

      :error ->
        # error: invalid room field
        conn
        |> assign(:prompt, true)
        |> assign(:field, key)
        |> render(BuildView, {:room, "invalid-field"})

    end
  end

  defp to_long(exit_name) when byte_size(exit_name) == 1 do
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

  defp to_long(exit_name) when byte_size(exit_name) == 2 do
    case exit_name do
      "nw" -> "northwest"
      "ne" -> "northeast"
      "sw" -> "southwest"
      "se" -> "southeast"
      _ -> exit_name
    end
  end

  defp to_long(exit_name), do: exit_name

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

  defp to_room_key(string) do
    case string do
      "name" -> :name
      "description" -> :description
      "x" -> :x
      "y" -> :y
      "z" -> :z
      "symbol" -> :symbol
      _ -> :error
    end
  end

  def maybe(:error), do: :error
  def maybe(result), do: {:ok, result}

end
