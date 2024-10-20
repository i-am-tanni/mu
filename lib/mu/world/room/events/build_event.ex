defmodule Mu.World.Room.BuildEvent do
  import Kalevala.World.Room.Context

  alias Mu.Character.BuildView
  alias Mu.Character.CommandView
  alias Mu.World.Kickoff
  alias Mu.World.Room
  alias Mu.World.Exit
  alias Mu.World.RoomIds
  alias Mu.World.WorldMap

  @default_symbol "[]"

  def dig(context, event = %{data: data}) do
    start_exit_name = data.start_exit_name
    local = context.data
    zone_id = local.zone_id
    room_string = "#{zone_id}.#{data.room_id}"

    cond do
      Enum.any?(context.data.exits, &Exit.matches?(&1, start_exit_name)) ->
        # error: exit name is already taken
        context
        |> assign(:exit_name, data.start_exit_name)
        |> assign(:self, event.acting_character)
        |> render(event.from_pid, BuildView, "exit-exists")
        |> render(event.from_pid, CommandView, "prompt")

      RoomIds.has_key?(room_string) ->
        # error: room id is unavailable
        context
        |> assign(:room_id, room_string)
        |> assign(:self, event.acting_character)
        |> render(event.from_pid, BuildView, "room-id-taken")
        |> render(event.from_pid, CommandView, "prompt")

      true ->
        start_room_id = local.id
        end_room_id = RoomIds.put(room_string)
        start_exit = Exit.basic_exit(data.start_exit_name, start_room_id, end_room_id)
        end_exit = Exit.basic_exit(data.end_exit_name, end_room_id, start_room_id)
        {x, y, z} = destination_coords(data.start_exit_name, local.x, local.y, local.z)

        room = %Room{
          id: end_room_id,
          zone_id: zone_id,
          x: x,
          y: y,
          z: z,
          symbol: @default_symbol,
          exits: [end_exit],
          name: "Default Room",
          description: "Default Description"
        }

        Kickoff.start_room(room)
        WorldMap.put(room)
        WorldMap.add_path(start_room_id, end_room_id)
        WorldMap.add_path(end_room_id, start_room_id)
        sorted_exits =
          [start_exit | context.data.exits]
          |> Enum.sort(&(exit_sort_order(&1) <= exit_sort_order(&2)))

        context
        |> put_data(:exits, sorted_exits)
        |> event(event.from_pid, self(), event.topic, %{exit_name: data.start_exit_name})
    end
  end

  defp destination_coords(start_exit_name, x, y, z) when is_integer(x) when is_integer(y) when is_integer(z) do
    case start_exit_name do
      "north" -> {x, y + 1, z}
      "south" -> {x, y - 1, z}
      "east" -> {x + 1, y, z}
      "west" -> {x - 1, y ,z}
      "up" -> {x, y, z + 1}
      "down" -> {x, y, z - 1}
      _ -> {nil, nil, nil}
    end
  end

  defp destination_coords(_, _, _, _), do: {nil, nil, nil}

  defp exit_sort_order(%Exit{exit_name: exit_name}) do
    case exit_name do
      "north"     -> 0
      "northeast" -> 1
      "east"      -> 2
      "southeast" -> 3
      "south"     -> 4
      "southwest" -> 5
      "west"      -> 6
      "northwest" -> 7
      "up"        -> 8
      "down"      -> 9
      _           -> 10
    end
  end

end
