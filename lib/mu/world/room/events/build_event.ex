defmodule Mu.World.Room.BuildEvent do
  import Kalevala.World.Room.Context

  alias Mu.Character.BuildView
  alias Mu.Character.CommandView
  alias Mu.World.Kickoff
  alias Mu.World.Room
  alias Mu.World.Zone
  alias Mu.World.Exit
  alias Mu.World.Exits
  alias Mu.World.RoomIds
  alias Mu.World.Mapper

  @default_symbol "[]"
  @world_map_keys [:x, :y, :z, :symbol]

  def room_stats(context, event) do
    context
    |> prompt(event.from_pid, BuildView, "rstat", %{room: context.data})
    |> prompt(event.from_pid, CommandView, "prompt", %{self: event.acting_character})
  end

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
          name: data.room_id,
          description: "Default Description"
        }

        Kickoff.start_room(room)
        Mapper.put(room)
        Mapper.path_create(start_room_id, end_room_id)
        Mapper.path_create(end_room_id, start_room_id)
        sorted_exits = Exits.sort([start_exit | context.data.exits])

        context
        |> put_data(:exits, sorted_exits)
        |> event(event.from_pid, self(), event.topic, %{exit_name: data.start_exit_name})
        |> event(zone_pid, self(), "put/room", %{room_id: room.id})
    end
  end

  def room_edit(context, %{data: %{key: key, val: val}} = event) do
    if key in @world_map_keys do
      context.data
      |> Map.put(key, val)
      |> Mapper.put()
    end

    context
    |> assign(:key, key)
    |> prompt(event.from_pid, BuildView, "rset")
    |> put_data(key, val)
    |> event(event.from_pid, self(), "room/look", %{})
  end

  def remove(context, event) do
    case event.data.type do
      "exit" -> exit_destroy(context, event)
    end
  end

  def edit_desc(context, event) do
    data = %{description: context.data.description}
    event(context, event.from_pid, self(), event.topic, data)
  end

  def exit_create(context, event) do
    from_pid = event.from_pid
    data = event.data

    %{zone_id: zone_id, end_template_id: end_template_id} = data
    zone_id = with :current <- zone_id, do: context.data.zone_id
    room_string = "#{zone_id}.#{end_template_id}"

    end_room_id =
      with :error <- Map.fetch(data, :end_room_id),
        do: RoomIds.get(room_string)

    case end_room_id do
      {:ok, end_room_id} ->
        # create new exit, add to room exits list, and sort
        local = context.data

        start_room_id = local.id
        end_template_id = if local.zone_id == zone_id, do: end_template_id, else: room_string
        start_exit_name = data.start_exit_name

        new_exit = Exit.new(start_exit_name, start_room_id, end_room_id, end_template_id)
        sorted_exits = Exits.sort([new_exit | reject_exit(context, start_exit_name)])

        Mapper.path_create(start_room_id, end_room_id)

        context =
          context
          |> put_data(:exits, sorted_exits)
          |> assign(:exit_name, start_exit_name)
          |> assign(:room_template_id, room_string)
          |> assign(:local_id, "#{local.zone_id}.#{local.template_id}")
          |> prompt(from_pid, BuildView, "exit-added")

        case data.bidirectional? do
          true -> bexit_create(context, event, end_room_id)
          false -> event(context, from_pid, self(), "room/look", %{})
        end

      :error ->
        acting_character = with nil <- event.acting_character, do: event.data.acting_character

        context
        |> assign(:room_id, room_string)
        |> assign(:self, acting_character)
        |> prompt(from_pid, BuildView, "room-id-missing")
        |> render(from_pid, CommandView, "prompt")

    end
  end

  # For bi-directional exits, pass exit info to partner room
  defp bexit_create(context, event, end_room_id) do

    case Room.whereis(end_room_id) |> maybe() do
      {:ok, end_room_pid} ->
        local = context.data
        data = event.data

        data = %{
          zone_id: local.zone_id,
          end_template_id: local.template_id,
          start_exit_name: data.end_exit_name,
          end_room_id: local.id,
          acting_character: event.acting_character,
          bidirectional?: false
        }

        event(context, end_room_pid, event.from_pid, event.topic, data)

      nil ->
        # Error: end_room_pid not found
        context
        |> assign(:room_id, end_room_id)
        |> render(event.from_pid, BuildView, "room-pid-missing")
    end
  end

  defp exit_destroy(context, event) do
    from_pid = event.from_pid
    %{keyword: keyword, opts: opts} = event.data

    case find_local_exit(context, keyword) |> maybe() do
      {:ok, room_exit} ->
        end_room_id = room_exit.end_room_id

        context =
          case _bi_directional? = Keyword.get(opts, :bi, false) do
            true -> bexit_destroy(context, event, end_room_id)
            false -> context
          end

        updated_exits = reject_exit(context, keyword)
        Mapper.path_destroy(room_exit.start_room_id, end_room_id)
        context = put_data(context, :exits, updated_exits)

        case _notify? = Keyword.get(opts, :notify, true) do
          true ->
            assigns = %{
              exit_name: room_exit.exit_name,
              end_template_id: room_exit.end_template_id,
            }

            prompt(context, from_pid, BuildView, "exit-destroy", assigns)

          false ->
            event(context, from_pid, self(), "room/look", %{})
        end

      nil ->
        # Error: exit keyword not found
        acting_character = with nil <- event.acting_character, do: event.data.acting_character

        context
        |> assign(:keyword, keyword)
        |> prompt(from_pid, BuildView, {:exit, "not-found"})
        |> render(from_pid, CommandView, "prompt", %{self: acting_character})
    end
  end

  # For destruction of bi-directional exits, pass destruction info to partner room
  defp bexit_destroy(context, event, end_room_id) do
    %{keyword: keyword, opts: opts} = event.data

    case Room.whereis(end_room_id) |> maybe() do
      {:ok, end_room_pid} ->
        opts = Keyword.delete(opts, :bi)
        data = %{
          type: "exit",
          keyword: Exit.opposite(keyword),
          opts: [notify: false] ++ opts,
          acting_character: event.acting_character
        }

        context
        |> event(end_room_pid, event.from_pid, event.topic, data)
        |> assign(:bi_directional?, true)

      nil ->
        # else, end_room_pid was not found
        context
        |> assign(:room_id, end_room_id)
        |> prompt(event.from_pid, BuildView, "room-pid-missing")
        |> assign(:bi_directional?, :false)
    end
  end

  defp maybe(nil), do: nil
  defp maybe(val), do: {:ok, val}

  defp find_local_exit(context, keyword) do
    Enum.find(context.data.exits, &Exit.matches?(&1, keyword))
  end

  defp reject_exit(context, keyword) do
    Enum.reject(context.data.exits, &Exit.matches?(&1, keyword))
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
