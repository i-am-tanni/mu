defmodule Mu.World.Kickoff do
  alias Kalevala.World.RoomSupervisor

  def start_zone(zone) do
    config = %{
      supervisor_name: Mu.World,
      callback_module: Mu.World.Zone
    }

    case GenServer.whereis(Kalevala.World.Zone.global_name(zone)) do
      nil ->
        Kalevala.World.start_zone(zone, config)

      pid ->
        Kalevala.World.Zone.update(pid, zone)
    end
  end

  def start_room(room) do
    config = %{
      supervisor_name: RoomSupervisor.global_name(room.zone_id),
      callback_module: Mu.World.Room
    }

    item_instances = Map.get(room, :item_instances, [])
    room = Map.delete(room, :item_instances)

    case GenServer.whereis(Kalevala.World.Room.global_name(room)) do
      nil ->
        Kalevala.World.start_room(room, item_instances, config)

      pid ->
        Kalevala.World.Room.update_items(pid, item_instances)
        Kalevala.World.Room.update(pid, room)
    end
  end
end
