defmodule Mu.World.Room.BuildEvent do
  import Kalevala.World.Room.Context

  alias Mu.Character.BuildView
  alias Mu.Character.CommandView
  alias Mu.World.Kickoff
  alias Mu.World.Room
  alias Mu.World.Zone
  alias Mu.World.Exit
  alias Mu.World.Exit.Door
  alias Mu.World.RoomIds
  alias Mu.World.WorldMap
  alias Mu.World.Item

  @default_symbol "[]"
  @world_map_keys [:x, :y, :z, :symbol]

  def dig(context, event = %{data: data}) do
    start_exit_name = data.start_exit_name
    local = context.data
    zone_id = local.zone_id
    to_room_template_id = data.room_id
    room_string = "#{zone_id}.#{to_room_template_id}"
    zone_pid = Zone.whereis(context.data.zone_id)

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

      is_nil(zone_pid) ->
        context
        |> assign(:zone_id, context.data.zone_id)
        |> assign(:self, event.acting_character)
        |> render(event.from_pid, BuildView, "zone-process-missing")
        |> render(event.from_pid, CommandView, "prompt")

      true ->
        start_room_id = local.id
        end_room_id = RoomIds.put(room_string)
        start_exit = Exit.new(data.start_exit_name, start_room_id, end_room_id, to_room_template_id)
        end_exit = Exit.new(data.end_exit_name, end_room_id, start_room_id, context.data.template_id)
        {x, y, z} = destination_coords(data.start_exit_name, local.x, local.y, local.z)

        room = %Room{
          id: end_room_id,
          template_id: data.room_id,
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
        sorted_exits = Exit.sort([start_exit | context.data.exits])

        context
        |> put_data(:exits, sorted_exits)
        |> event(event.from_pid, self(), event.topic, %{exit_name: data.start_exit_name})
        |> event(zone_pid, self(), "put/room", %{room_id: room.id})
    end
  end

  def set(context, %{data: %{key: key, val: val}} = event) do
    if key in @world_map_keys do
      context.data |> Map.put(key, val) |> WorldMap.put()
    end

    context
    |> assign(:key, key)
    |> prompt(event.from_pid, BuildView, "set")
    |> put_data(key, val)
    |> event(event.from_pid, self(), "room/look", %{})
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

end
