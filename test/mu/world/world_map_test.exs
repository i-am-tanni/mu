defmodule Mu.World.WorldMapTest do
  use ExUnit.Case

  alias Mu.World.WorldMap

  test "mini map test1" do
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
      exits: [%{to: 1}],
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
      id: "test",
      rooms: [room0, room1, room2, room3, room4]
    }

    WorldMap.add_zone(zone)

    expect = """
          **
          **
        <>
      **
      **
    """

    expect = "      **  \n      **  \n    <>    \n  **      \n  **      "

    result =
      WorldMap.mini_map(0)
      |> Enum.intersperse("\n")
      |> to_string()

    assert expect == result
  end

end
