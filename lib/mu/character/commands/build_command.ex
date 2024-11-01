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
  alias Mu.Character.BuildCommand

  # for new_zone()
  alias Mu.World.Zone
  alias Mu.World.Room
  alias Mu.World.RoomIds
  alias Mu.World.WorldMap
  alias Mu.World.Kickoff
  alias Mu.Character.TeleportAction
  alias Mu.Character.Action


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
        |> prompt(BuildView, "invalid-exit-name")

      end_exit_name not in @valid_exit_names ->
        conn
        |> assign(:prompt, true)
        |> assign(:exit_name, end_exit_name)
        |> prompt(BuildView, "invalid-exit-name")

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

  def new_zone(conn, params) do
    zone_id = Inflex.camelize(params["zone_id"])
    room_id = Inflex.underscore(params["room_id"])
    room_string = "#{zone_id}.#{room_id}"

    case Mu.World.RoomIds.has_key?(room_string) do
      true ->
        # error: room id is unavailable
        conn
        |> assign(:prompt, true)
        |> assign(:room_id, room_string)
        |> render(BuildView, "room-id-taken")

      false ->
        end_room_id = RoomIds.put(room_string)

        room = %Room{
          id: end_room_id,
          template_id: room_id,
          zone_id: zone_id,
          x: 0,
          y: 0,
          z: 0,
          symbol: "[]",
          exits: [],
          name: "Default Room",
          description: "Default Description"
        }

        zone = %Zone{
          id: zone_id,
          name: "Default Zone Name",
          characters: [],
          items: [],
          rooms: MapSet.new([end_room_id])
        }

        Kickoff.start_zone(zone)
        Kickoff.start_room(room)
        WorldMap.put(room)

        conn
        |> Action.cancel()
        |> TeleportAction.run(%{room_id: end_room_id})
    end
  end

  @doc """
  Write zone file to disk
  """
  def zone_save(conn, _params) do
    conn
    |> assign(:prompt, :false)
    |> event("zone/save", %{})
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

end
