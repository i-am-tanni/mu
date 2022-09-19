defmodule Mu do
  def test() do
    alias Mu.World.{Room, Zone, Kickoff}

    zone = %Zone{id: 1}
    room = %Room{id: 1, zone_id: zone.id}

    Kickoff.start_zone(zone)
    Kickoff.start_room(room)
  end
end
