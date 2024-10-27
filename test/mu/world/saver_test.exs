defmodule Mu.World.SaverTest do
  use ExUnit.Case

  alias Mu.World.Saver
  alias Mu.World.Zone
  alias Mu.World.Room

  test "simple save" do
    room = %Room{
      template_id: "test_room",
      x: 0,
      y: 0,
      z: 0,
      symbol: "[]",
      name: "test room",
      description: "test description",
      exits: [],
      extra_descs: []
    }

    zone = %Zone{
      id: "zone",
      name: "test zone",
      characters: [],
      rooms: [room],
      items: [],
      character_spawner: %{}
    }

    saved? = :ok = Saver.save_zone(zone, "test_zone")
    if saved?, do:
      File.rm!("data/world/test_zone.json")

    assert saved?
  end


end
