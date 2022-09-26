defmodule Mu do
  def test() do
    alias Mu.World.{Room, Zone, Kickoff}
    alias Kalevala.World.Exit

    exits1 = [
      %Exit{
        id: nil,
        exit_name: "north",
        start_room_id: 1,
        end_room_id: 2
      }
    ]

    exits2 = [
      %Exit{
        id: nil,
        exit_name: "south",
        start_room_id: 2,
        end_room_id: 1
      }
    ]

    zone = %Zone{id: 1}
    room1 = %Room{id: 1, zone_id: zone.id, exits: exits1}
    room2 = %Room{id: 2, zone_id: zone.id, exits: exits2}

    Kickoff.start_zone(zone)
    Enum.each([room1, room2], &Kickoff.start_room/1)
  end
end
