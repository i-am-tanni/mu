defmodule Mu.Character.BuildCommand.Room do
  use Kalevala.Character.Command

  def set(conn, params) do
    key = key_to_atom(params["key"])
    val = prepare(params["val"], key)

    cond do
      key == :error ->
        # error: invalid room field
        conn
        |> assign(:prompt, true)
        |> assign(:field, key)
        |> prompt(BuildView, {:room, "invalid-field"})

      val == :error ->
        # error: could not validate room value
        conn
        |> assign(:prompt, true)
        |> assign(:key, key)
        |> assign(:val, val)
        |> prompt(BuildView, {:room, "invalid-val"})

      true ->
        params = %{key: key, val: val}

        conn
        |> event("room/set", params)
        |> assign(:prompt, false)
    end
  end

  defp key_to_atom(key) do
    case key do
      "name" -> :name
      "description" -> :description
      "x" -> :x
      "y" -> :y
      "z" -> :z
      "symbol" -> :symbol
      _ -> :error
    end
  end

  defp prepare(_, :error), do: :error

  defp prepare(val, key) when key not in [:x, :y, :z, :symbol], do: val

  defp prepare(val, key) when key in [:x, :y, :z] do
    case Integer.parse(val) do
      {val, _} -> val
      :error -> :error
    end
  end

  defp prepare(val, :symbol) do
    case String.length(val) >= 2 do
      true -> String.slice(val, 0..1)
      false -> :error
    end
  end

  defp prepare(_, _), do: :error
end

defmodule Mu.Character.BuildCommand do
  @moduledoc """
  Commands for building areas.
  """
  use Kalevala.Character.Command
  alias Mu.Character.BuildView
  alias __MODULE__

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

  def set_room(conn, params), do: BuildCommand.Room.set(conn, params)

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

end
