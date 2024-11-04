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
  alias Mu.World.Exit

  # for new_zone()
  alias Mu.World.Zone
  alias Mu.World.Room
  alias Mu.World.RoomIds
  alias Mu.World.WorldMap
  alias Mu.World.Kickoff
  alias Mu.Character.TeleportAction
  alias Mu.Character.Action

  @doc """
  Syntax: @dig <destination_id> <start_exit_keyword> <end_exit_keyword>

  Sends the room a request to dig a two-way exit to the destination id.
  """
  def dig(conn, params) do
    start_exit_name = Exit.to_long(params["start_exit_name"])

    end_exit_name =
      case params["end_exit_name"] do
        nil -> Exit.opposite(start_exit_name)
        exit_name -> Exit.to_long(exit_name)
      end

    cond do
      not Exit.valid?(start_exit_name) ->
        conn
        |> assign(:prompt, true)
        |> assign(:exit_name, start_exit_name)
        |> prompt(BuildView, "invalid-exit-name")

      not Exit.valid?(end_exit_name) ->
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

  @doc """
  Syntax: @new_zone <zone_id> <room_id>

  Creates a new room (room_id) in new or existing zone_id.
  """
  def new_zone(conn, params) do
    zone_id = Inflex.camelize(params["zone_id"])
    template_id = Inflex.underscore(params["room_id"])
    room_string = "#{zone_id}.#{template_id}"

    case RoomIds.has_key?(room_string) do
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
          template_id: template_id,
          zone_id: zone_id,
          x: 0,
          y: 0,
          z: 0,
          symbol: "[]",
          exits: [],
          name: template_id,
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
  Syntax: @save_zone

  Write current zone to a file on disk.
  """
  def zone_save(conn, _params) do
    conn
    |> assign(:prompt, :false)
    |> event("zone/save", %{})
  end

  @doc """
  Syntax: @put_exit <exit_keyword> <destination_id>

  Note: destination_id is in "Zone.room_template_id" or "template_id" format
  If no Zone destination is supplied, the current zone is assumed.

  Places an exit to destination_id usable with the supplied exit_keyword
  in the current room.
  """
  def put_exit(conn, params) do
    exit_name = Exit.to_long(params["exit_name"])
    case Exit.valid?(exit_name) do
      true ->
        to_template_id = params["destination_id"]
        [room_template_id | zone_id] = String.split(to_template_id, ".") |> Enum.reverse()
        room_template_id = Inflex.underscore(room_template_id)
        zone_template_id =
          case Enum.reverse(zone_id) do
            [] -> :current
            items -> Enum.join(items, ".") |> Inflex.camelize()
          end

        params = %{
          zone_template_id: zone_template_id,
          room_template_id: room_template_id,
          exit_name: exit_name
        }

      conn
      |> assign(:prompt, :false)
      |> event("put-exit", params)

    false ->
      # Error: Invalid Exit Name
      conn
      |> assign(:exit_name, exit_name)
      |> assign(:prompt, true)
      |> prompt(BuildView, "invalid-exit-name")
    end
  end

end
