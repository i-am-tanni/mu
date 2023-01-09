defmodule Mu do
  def test_map() do
    %{
      zone: %{
        id: 1
      },
      rooms: %{
        1 => %{
          name: "North Room",
          description: "It's cold up here.",
          exits: %{
            south: 2
          },
          doors: %{
            south: %{id: 1}
          }
        },
        2 => %{
          name: "South Room",
          description: "It's warmer down here.",
          exits: %{
            north: 1
          },
          doors: %{
            north: %{id: 1}
          }
        }
      },
      items: %{
        "generic:potion" => %{
          keywords: ["potion", "red", "flask"],
          name: "a red potion",
          dropped_name: "A lurid red flask catches your eye.",
          description: "This potion is said to have potent healing properties."
        }
      }
    }
  end

  def test() do
    alias Mu.World.Room
    alias Mu.World.Zone
    alias Mu.World.Kickoff
    alias Mu.World.Exit
    alias Mu.World.Exit.Door

    exits1 = [
      %Exit{
        id: 1,
        exit_name: "north",
        start_room_id: 1,
        end_room_id: 2,
        hidden?: false,
        secret?: false,
        door: %Door{
          id: 1,
          closed?: true,
          locked?: false
        }
      }
    ]

    exits2 = [
      %Exit{
        id: 2,
        exit_name: "south",
        start_room_id: 2,
        end_room_id: 1,
        hidden?: false,
        secret?: false,
        door: %Door{
          id: 1,
          closed?: true,
          locked?: false
        }
      }
    ]

    zone = %Zone{id: 1}
    south = %Room{id: 1, zone_id: zone.id, exits: exits1, name: "South Room"}
    north = %Room{id: 2, zone_id: zone.id, exits: exits2, name: "North Room"}

    item = %Mu.World.Item{
      id: "generic:potion",
      keywords: ["potion", "red", "flask"],
      name: "a red potion",
      dropped_name: "A lurid red flask catches your eye.",
      description: "This potion is said to have potent healing properties.",
      callback_module: Mu.World.Item,
      meta: %{},
      verbs: [:get, :drop]
    }

    Kickoff.start_zone(zone)
    Kickoff.cache_item(item)
    Enum.each([south, north], &Kickoff.start_room/1)
  end
end
