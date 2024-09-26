defmodule Mu.World.WorldMapTest do
  use ExUnit.Case

  alias Mu.World.WorldMap

  test "simple mini map" do
    room0 = %{
      id: 0,
      symbol: "**",
      exits: [%{to: 1}, %{to: 3}],
      x: 0,
      y: 0,
      z: 0
    }

    room1 = %{
      id: 1,
      symbol: "**",
      exits: [%{to: 0}, %{to: 2}],
      x: 1,
      y: 1,
      z: 0
    }

    room2 = %{
      id: 2,
      symbol: "**",
      exits: [%{to: "1"}],
      x: 1,
      y: 2,
      z: 0
    }

    room3 = %{
      id: 3,
      symbol: "**",
      exits: [%{to: 0}, %{to: 4}],
      x: -1,
      y: -1,
      z: 0
    }

    room4 = %{
      id: 4,
      symbol: "**",
      exits: [%{to: 3}],
      x: -1,
      y: -2,
      z: 0
    }

    zone = %Mu.World.Zone{
      id: "test1",
      rooms: [room0, room1, room2, room3, room4]
    }

    WorldMap.add_zone(zone)

    expect = "      **  \n      **  \n    <>    \n  **      \n  **      "

    result =
      WorldMap.mini_map(0)
      |> Enum.intersperse("\n")
      |> to_string()

    # clean up
    WorldMap.reset()

    assert expect == result
  end

  test "mini map depth" do
    rooms = [
    %{
      id: 0,
      symbol: "**",
      exits: [%{to: 1}],
      x: 2,
      y: 2,
      z: 0
    },
    %{
      id: 1,
      symbol: "**",
      exits: [%{to: 2}, %{to: 0}],
      x: 2,
      y: 1,
      z: 0
    },
    %{
      id: 2,
      symbol: "**",
      exits: [%{to: 3}, %{to: 1}],
      x: 2,
      y: 0,
      z: 0
    },
    %{
      id: 3,
      symbol: "**",
      exits: [%{to: 4}, %{to: 2}],
      x: 3,
      y: 0,
      z: 0
    },
    %{
      id: 4,
      symbol: "**",
      exits: [%{to: 5}, %{to: 3}],
      x: 4,
      y: 0,
      z: 0
    },
    %{
      id: 5,
      symbol: "**",
      exits: [%{to: 6}, %{to: 4}],
      x: 4,
      y: 1,
      z: 0
    },
    %{
      ## since max_depth == 5, this node should be ignored
      id: 6,
      symbol: "**",
      exits: [%{to: 5}],
      x: 4,
      y: 2,
      z: 0
    }
  ]

  zone = %Mu.World.Zone{
    id: "test2",
    rooms: rooms
  }

  WorldMap.add_zone(zone)


  expect = "          \n          \n    <>    \n    **  **\n    ******"

  result =
    WorldMap.mini_map(0)
    |> Enum.intersperse("\n")
    |> to_string()

  #IO.inspect(result, label: "RESULT")

  assert expect == result

  end

end
