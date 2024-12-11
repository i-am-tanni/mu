defmodule Mu.Character.BuildCommand.Room do
  use Kalevala.Character.Command

  alias Mu.Character.WriteController
  alias Mu.Character.BuildView

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

      val == :error and is_nil(params["val"]) ->
        conn
        |> assign(:prompt, true)
        |> assign(:key, key)
        |> prompt(BuildView, {:room, "missing-val"})

      val == :error ->
        # error: could not validate room value
        conn
        |> assign(:prompt, true)
        |> assign(:key, key)
        |> assign(:val, params["val"])
        |> prompt(BuildView, {:room, "invalid-val"})

      key == :description ->
        conn
        |> assign(:prompt, false)
        |> event("redit/desc")

      true ->
        data = %{key: key, val: val}

        conn
        |> event("room/set", data)
        |> assign(:prompt, false)
    end
  end

  defp key_to_atom(key) do
    case key do
      "name" -> :name
      "desc" -> :description
      "x" -> :x
      "y" -> :y
      "z" -> :z
      "symbol" -> :symbol
      _ -> :error
    end
  end

  defp prepare(_, :error), do: :error

  defp prepare(nil, key) when key not in [:description], do: :error

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
  alias Mu.World.Mapper
  alias Mu.World.Kickoff
  alias Mu.Character.TeleportAction
  alias Mu.Character.Action

  @doc """
  Syntax: @dig <destination_id> <start_exit_keyword> <end_exit_keyword>

  Sends the room a request to dig a two-way exit to the destination id.
  """
  def dig(conn, params) do
    start_exit_name = to_long(params["start_exit_name"])

    end_exit_name =
      case params["end_exit_name"] do
        nil -> opposite(start_exit_name)
        exit_name -> to_long(exit_name)
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

  def redit(conn, params), do: BuildCommand.Room.set(conn, params)

  @doc """
  Syntax: @znew <zone_id> <room_id>

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
        Mapper.put(room)

        conn
        |> Action.cancel()
        |> TeleportAction.run(%{room_id: end_room_id})
    end
  end

  @doc """
  Syntax: @zsave

  Write current zone to a file on disk.
  """
  def zone_save(conn, _params) do
    conn
    |> assign(:prompt, :false)
    |> event("zone/save", %{})
  end

  @doc """
  Syntax: @rexit <destination_id> <start_exit_keyword> (end_exit_keyword)

  Note: destination_id is in "Zone.room_template_id" or "template_id" format
  If no Zone destination is supplied, the current zone is assumed.

  Places an exit to destination_id usable with the supplied exit_keyword
  in the current room. If an optional end_exit_keyword is supplied,
  then the exit will be bi-directional.
  """
  def put_exit(conn, params) do
    start_exit_name = to_long(params["start_exit_name"])
    end_exit_name = to_long(params["end_exit_name"])

    cond do
      not Exit.valid?(start_exit_name) ->
        # Error: Invalid Exit Name
        conn
        |> assign(:exit_name, start_exit_name)
        |> assign(:prompt, true)
        |> prompt(BuildView, "invalid-exit-name")

      end_exit_name && not Exit.valid?(end_exit_name) ->
        # Error: Invalid Exit Name
        conn
        |> assign(:exit_name, end_exit_name)
        |> assign(:prompt, true)
        |> prompt(BuildView, "invalid-exit-name")

      true ->
        to_template_id = params["destination_id"]
        [room_template_id | zone_id] = String.split(to_template_id, ".") |> Enum.reverse()
        room_template_id = Inflex.underscore(room_template_id)
        zone_template_id =
          case Enum.reverse(zone_id) do
            [] -> :current
            items -> Enum.join(items, ".") |> Inflex.camelize()
          end

        data = %{
          zone_id: zone_template_id,
          end_template_id: room_template_id,
          start_exit_name: start_exit_name,
          end_exit_name: end_exit_name,
          bidirectional?: !is_nil(end_exit_name)
        }

      conn
      |> assign(:prompt, :false)
      |> event("exit/create", data)
    end
  end

  @doc """
  Syntax: @rbexit <destination_id> <start_exit_keyword>

  Note: destination_id is in "Zone.room_template_id" or "template_id" format
  If no Zone destination is supplied, the current zone is assumed.

  Places a bi-directional exit to destination_id usable with the supplied exit_keyword
  in the current room.
  """
  def put_bexit(conn, params) do
    end_exit_name = opposite(params["start_exit_name"])
    params = Map.put(params, "end_exit_name", end_exit_name)
    put_exit(conn, params)
  end

  def room_stats(conn, _params) do
    conn
    |> assign(:prompt, false)
    |> event("rstat")
  end

  @doc """
  Syntax: @rm <type> <keyword> (opts)

  Removes something from the room.

  ## Options
  Opts is an optional keyword list.

  # Exit Options
  bi:boolean - if true, will remove both sides of the exit (default false)
  """

  def remove(conn, params) do
    type = params["type"]
    opts = to_keyword_list(type, Map.get(params, "opts", []))

    cond do
      type not in ~w(exit) ->
        # Error: invalid type to remove
        conn
        |> assign(:type, type)
        |> assign(:prompt, true)
        |> prompt(BuildView, "invalid-type")

      match?({:error, _}, opts) ->
        # Error: invalid options
        {:error, errors} = opts

        conn
        |> assign(:type, type)
        |> assign(:errors, errors)
        |> assign(:prompt, true)
        |> prompt(BuildView, "invalid-option")

      true ->
        {:ok, opts} = opts

        data = %{
          type: type,
          keyword: params["keyword"],
          opts: opts
        }

        event(conn, "room/remove", data)
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

  defp to_keyword_list(_, []), do: {:ok, []}

  defp to_keyword_list(type, opts) do
    {kw_list, errors} =
      Enum.map_reduce(opts, [], fn {key, val}, acc ->
        case option_to_atom(type, key) do
          {:ok, atom} -> {{atom, val}, acc}
          :error -> {:error, [key | acc]}
        end
      end)

    case Enum.empty?(errors) do
      true -> {:ok, kw_list}
      false -> {:error, errors}
    end
  end

  defp option_to_atom("exit", key) do
    result =
      case key do
        "bi" -> :bi
        _ -> :error
      end

    if result != :error, do: {:ok, result}, else: :error
  end
end
