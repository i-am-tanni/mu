defmodule Mu.World.Kickoff do
  alias Kalevala.World.RoomSupervisor

  def start_room(room) do
    config = %{
      supervisor_name: RoomSupervisor.global_name(room.zone_id),
      callback_module: Mu.World.Room
    }
  end
end
