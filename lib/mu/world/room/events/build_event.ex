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

  def exit_create(context, event) do
    # start render vars
    acting_character = with nil <- event.acting_character, do: event.data.acting_character
    from_pid = event.from_pid
    # end render vars

    data = event.data
    end_template_id = data.room_template_id
    zone_id = with :current <- data.zone_id, do: context.data.zone_id
    room_string = "#{zone_id}.#{end_template_id}"

    end_room_id =
      case Map.get(data, :end_room_id) do
        nil -> RoomIds.get(room_string)
        id -> {:ok, id}
      end

    case end_room_id do
      {:ok, end_room_id} ->
        # create new exit, add to room exits list, and sort
        local = context.data
        start_exit_name = data.start_exit_name
        start_room_id = local.id
        end_template_id = if local.zone_id == zone_id, do: end_template_id, else: room_string

        new_exit = Exit.new(start_exit_name, start_room_id, end_room_id, end_template_id)

        sorted_exits =
          [new_exit | Enum.reject(context.data.exits, &Exit.matches?(&1, start_exit_name))]
          |> Exits.sort()

        Mapper.path_create(start_room_id, end_room_id)

        context =
          context
          |> put_data(:exits, sorted_exits)
          |> assign(:exit_name, start_exit_name)
          |> assign(:room_template_id, room_string)
          |> assign(:local_id, "#{local.zone_id}.#{local.template_id}")
          |> prompt(from_pid, BuildView, "exit-added")

        end_exit_name = Map.get(data, :end_exit_name)
        bi_directional? = is_binary(end_exit_name)

        case bi_directional? && Room.whereis(end_room_id) do
          end_room_pid when is_pid(end_room_pid) ->
            # if bi-directional and end_room_pid found, pass exit info to partner room
            local = context.data

            params = %{
              zone_id: local.zone_id,
              room_template_id: local.template_id,
              start_exit_name: end_exit_name,
              end_room_id: local.id,
              acting_character: event.acting_character
            }

            event(context, end_room_pid, event.from_pid, event.topic, params)

          nil when bi_directional? ->
            # Error: end_room_pid not found
            context
            |> assign(:room_id, end_room_id)
            |> render(from_pid, BuildView, "room-pid-missing")

          _ ->
            # if not bi-directional, finish by looking at the result
            event(context, from_pid, self(), "room/look", %{})
        end

      :error ->
        context
        |> assign(:room_id, room_string)
        |> assign(:self, acting_character)
        |> prompt(from_pid, BuildView, "room-id-missing")
        |> render(from_pid, CommandView, "prompt")

    end
  end

  defp exit_destroy(context, event) do
    # start render vars
    from_pid = event.from_pid
    acting_character = with nil <- event.acting_character, do: event.data.acting_character
    # end render vars

    %{keyword: keyword, opts: opts} = event.data

    case Enum.find(context.data.exits, &Exit.matches?(&1, keyword)) do
      room_exit when is_struct(room_exit, Exit) ->
        end_room_id = room_exit.end_room_id

        # consider if the exit is bi-directional and notify partner room if that is the case
        bi_directional? = Keyword.get(opts, :bi, false)
        context =
          with context when bi_directional? <- context do
            case Room.whereis(end_room_id) do
              end_room_pid when is_pid(end_room_pid) ->
                # if bi-directional and end_room_pid is an active process
                opts = Keyword.delete(opts, :bi)
                data = %{
                  type: "exit",
                  keyword: Exit.opposite(keyword),
                  opts: [notify: false] ++ opts,
                  acting_character: acting_character
                }
                context
                |> event(end_room_pid, from_pid, event.topic, data)
                |> assign(:bi_directional?, true)

              nil ->
                # else, end_room_pid was not found
                context
                |> assign(:room_id, end_room_id)
                |> prompt(from_pid, BuildView, "room-pid-missing")
                |> assign(:bi_directional?, :false)
            end
          end

        # only notify on destruction of the first side of an exit
        notify? = Keyword.get(opts, :notify, true)
        context =
          with context when notify? <- context do
            assigns = %{
              exit_name: room_exit.exit_name,
              end_template_id: room_exit.end_template_id,
            }

            prompt(context, from_pid, BuildView, "exit-destroy", assigns)
          end

        updated_exits = Enum.reject(context.data.exits, &Exit.matches?(&1, keyword))
        Mapper.path_destroy(room_exit.start_room_id, end_room_id)

        context
        |> put_data(:exits, updated_exits)
        |> event(from_pid, self(), "room/look", %{})

      nil ->
        # Error: exit keyword not found
        context
        |> assign(:keyword, keyword)
        |> prompt(from_pid, BuildView, {:exit, "not-found"})
        |> render(from_pid, CommandView, "prompt", %{self: acting_character})
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

end
