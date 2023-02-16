defmodule Mu.World.Loader do
  alias Mu.World.Zone
  alias Mu.World.Room
  alias Mu.World.Exit
  alias Mu.World.Exit.Door
  alias Mu.World.Item
  alias Mu.World

  @paths %{
    world_path: "data/world"
  }

  @doc """
  Load zone files into Mu structs
  """
  def load(paths \\ %{}) do
    paths = Map.merge(paths, @paths)

    world_data = load_folder(paths.world_path, ".json", &merge_world_data/1)

    zones = Enum.map(world_data, &parse_zone/1)

    parse_world(zones)
  end

  @doc """
  Strip a zone of extra information that Kalevala doesn't care about
  """
  def strip_zone(zone) do
    room_ids = Enum.reduce(zone.rooms, MapSet.new(), &MapSet.put(&2, &1.id))

    zone
    |> Map.put(:characters, [])
    |> Map.put(:items, [])
    |> Map.put(:rooms, room_ids)
  end

  defp load_folder(path, file_extension, merge_fun) do
    File.ls!(path)
    |> Enum.filter(fn file ->
      String.ends_with?(file, file_extension)
    end)
    |> Enum.map(fn file ->
      File.read!(Path.join(path, file))
    end)
    |> Enum.map(&Jason.decode!/1)
    |> Enum.flat_map(merge_fun)
    |> Enum.into(%{})
  end

  defp merge_world_data(zone_data) do
    %{"zone" => %{"id" => id}} = zone_data
    [{id, zone_data}]
  end

  defp parse_zone({key, zone_data}, context \\ %{}) do
    zone = %Zone{}
    id = key
    context = Map.merge(context, %{zone_id: key})
    %{"zone" => %{"name" => name}} = zone_data

    rooms =
      Map.get(zone_data, "rooms", [])
      |> Enum.map(&keys_to_atoms/1)
      |> Enum.map(&parse_room(&1, context))

    items =
      Map.get(zone_data, "items", [])
      |> Enum.map(&keys_to_atoms/1)
      |> Enum.map(&parse_item(&1, context))

    %{zone | id: id, name: name, rooms: rooms, items: items}
  end

  defp parse_room({key, room}, context) do
    doors = Map.get(room, :doors, %{})
    id = World.parse_id(key)
    exit_context = %{doors: doors, room_id: id}

    exits =
      Map.get(room, :exits, [])
      |> Enum.map(&parse_exit(&1, exit_context))

    %Room{
      id: id,
      zone_id: context.zone_id,
      name: room.name,
      description: room.description,
      exits: exits
    }
  end

  defp parse_exit({key, room_exit}, context) do
    door = Map.get(context.doors, key)

    case room_exit do
      %{} ->
        %Exit{
          # TODO
        }

      to_room ->
        door = parse_door(door)
        type = if is_nil(door), do: :normal, else: :door

        %Exit{
          type: type,
          exit_name: key,
          start_room_id: context.room_id,
          end_room_id: to_room,
          hidden?: false,
          secret?: false,
          door: door
        }
    end
  end

  defp parse_door(door) do
    with %{} <- door do
      %Door{
        id: Map.fetch!(door, "id"),
        closed?: true,
        locked?: Map.has_key?(door, :key_id)
      }
    end
  end

  defp parse_item({key, item}, _context) do
    %Item{
      id: key,
      keywords: item.keywords,
      name: item.name,
      dropped_name: item.dropped_name,
      description: item.description,
      wear_slot: item[:wear_slot],
      callback_module: Item,
      meta: %{},
      verbs: [:get, :drop]
    }
  end

  defp parse_world(zones) do
    %World{zones: zones}
    |> split_out_rooms()
    |> split_out_items
  end

  defp split_out_rooms(world) do
    rooms =
      Enum.flat_map(world.zones, fn zone ->
        Map.get(zone, :rooms, [])
      end)

    %{world | rooms: rooms}
  end

  defp split_out_items(world) do
    items =
      Enum.flat_map(world.zones, fn zone ->
        Map.get(zone, :items, [])
      end)

    %{world | items: items}
  end

  defp keys_to_atoms({key, map = %{}}) do
    val =
      Enum.map(map, fn {key, value} ->
        {String.to_atom(key), value}
      end)
      |> Enum.into(%{})

    {key, val}
  end
end
