defmodule Mu.World.Saver.ZoneFile do
  @derive Jason.Encoder
  defstruct [:zone, rooms: [], items: []]
end

defmodule Mu.World.Saver do
  @moduledoc """
  The opposite of the loader. Saves files to disk
  """

  alias Mu.World.ZoneCache
  alias Mu.World.Saver.ZoneFile

  @paths %{
    world_path: "data/world"
  }

  def save_area(zone_id, file_name, paths \\ %{}) do
    paths = Map.merge(paths, @paths)
    zone = ZoneCache.get!(zone_id)

    file =
      %ZoneFile{}
      |> prepare_zone(zone)
      |> prepare_rooms(zone)
      |> prepare_items(zone)
      |> Jason.encode!(pretty: true)

    File.write!(Path.join(paths.world_path, "#{file_name}.json"), file)
  end

  defp prepare_zone(file, zone) do
    zone = %{
      id: zone.id,
      name: zone.name
    }

    %{file | zone: zone}
  end

  defp prepare_rooms(file, zone) when zone.rooms == [], do: file

  defp prepare_rooms(file, zone) do
    rooms =
      zone.rooms
      |> Enum.map(fn room ->
        {to_string(room.id), prepare_room(room)}
      end)
      |> Enum.into(%{})

    %{file | rooms: rooms}
  end

  defp prepare_items(file, zone) when zone.items == [], do: file

  defp prepare_items(file, zone) do
    items =
      zone.items
      |> Enum.map(fn item ->
        {to_string(item.id), prepare_item(item)}
      end)
      |> Enum.into(%{})

    %{file | items: items}
  end

  defp prepare_room(room) do
    exits =
      room.exits
      |> Enum.map(&prepare_exit/1)
      |> Enum.into(%{})

    doors =
      room.exits
      |> Enum.map(&prepare_door/1)
      |> Enum.reject(&is_nil(&1))
      |> Enum.into(%{})

    room = %{
      name: room.name,
      description: room.description,
      exits: exits
    }

    case doors != %{} do
      true -> Map.put(room, :doors, doors)
      false -> room
    end
  end

  defp prepare_exit(room_exit) do
    {room_exit.exit_name, room_exit.end_room_id}
  end

  defp prepare_door(%{door: door}) when is_nil(door), do: nil

  defp prepare_door(%{exit_name: exit_name, door: door}) do
    door = %{
      id: door.id
    }

    {exit_name, door}
  end

  defp prepare_item(item) do
    %{
      description: item.description,
      dropped_name: item.dropped_name,
      keywords: item.keywords,
      name: item.name
    }
  end
end
