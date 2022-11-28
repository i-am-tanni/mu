defmodule Mu do
  def test() do
    alias Mu.World.{Room, Zone, Kickoff}
    alias Kalevala.World.Exit

    exits1 = [
      %Exit{
        id: 1,
        exit_name: "north",
        start_room_id: 1,
        end_room_id: 2
      }
    ]

    exits2 = [
      %Exit{
        id: 2,
        exit_name: "south",
        start_room_id: 2,
        end_room_id: 1
      }
    ]

    zone = %Zone{id: 1}
    south = %Room{id: 1, zone_id: zone.id, exits: exits1, name: "South Room"}
    north = %Room{id: 2, zone_id: zone.id, exits: exits2, name: "North Room"}

    Kickoff.start_zone(zone)
    Enum.each([south, north], &Kickoff.start_room/1)
  end
end
