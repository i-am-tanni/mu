defmodule Mu.World.Saver do
  @moduledoc """
  The opposite of the loader. Saves files to disk
  """

  alias Mu.World.Zone
  alias Mu.World.ZoneCache

  @paths %{
    world_path: "data/world"
  }

  def save_area(zone_id, paths \\ %{}) do
    paths = Map.merge(paths, @paths)
    zone = prepare_zone(zone_id)
    json = Jason.encode!(zone, pretty: true)
    File.write!(~s(#{paths.world_path}#{zone.name}.json), json)
  end

  defp prepare_zone(zone_id) do
    zone = ZoneCache.get(zone_id)
    rooms = prepare_rooms(zone.rooms)

    %Zone{id: zone_id, name: zone.name, rooms: rooms}
  end

  defp prepare_rooms(room_ids) do
    room_ids
    |> Enum.map(&Mu.World.Room.get/1)
  end
end
