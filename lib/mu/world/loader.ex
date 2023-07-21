defmodule Mu.World.Loader do
  alias Mu.World.Zone
  alias Mu.World.Room
  alias Mu.World.Exit
  alias Mu.World.Exit.Door
  alias Mu.World.Item
  alias Mu.World
  alias Kalevala.Character
  alias Mu.World.Zone.Spawner.SpawnRules
  alias Mu.World.Zone.Spawner

  @paths %{
    world_path: "data/world",
    verbs_path: "data/verbs.json"
  }

  @doc """
  Load zone files into Mu structs
  """
  def load(paths \\ %{}) do
    paths = Map.merge(paths, @paths)

    world_data = load_folder(paths.world_path, ".json", &merge_world_data/1)

    context = %{
      verbs: parse_verbs(Jason.decode!(File.read!(paths.verbs_path)))
    }

    zones = Enum.map(world_data, &parse_zone(&1, context))

    parse_world(zones)
  end

  @doc """
  Strip a zone of extra information that Kalevala doesn't care about
  """
  def strip_zone(zone) do
    room_ids = Enum.reduce(zone.rooms, MapSet.new(), &MapSet.put(&2, &1.id))

    zone
    |> Map.put(:characters, [])
    |> Map.put(:items, [])
    |> Map.put(:rooms, room_ids)
  end

  defp load_folder(path, file_extension, merge_fun) do
    File.ls!(path)
    |> Enum.filter(fn file ->
      String.ends_with?(file, file_extension)
    end)
    |> Enum.map(fn file ->
      File.read!(Path.join(path, file))
    end)
    |> Enum.map(&Jason.decode!/1)
    |> Enum.flat_map(merge_fun)
    |> Enum.into(%{})
  end

  defp merge_world_data(zone_data) do
    %{"zone" => %{"id" => id}} = zone_data
    [{id, zone_data}]
  end

  defp parse_zone({key, zone_data}, context) do
    zone = %Zone{}
    id = key
    context = Map.merge(context, %{zone_id: key})
    %{"zone" => %{"name" => name}} = zone_data

    rooms =
      Map.get(zone_data, "rooms", [])
      |> Enum.map(&keys_to_atoms/1)
      |> Enum.map(&parse_room(&1, context))

    items =
      Map.get(zone_data, "items", [])
      |> Enum.map(&keys_to_atoms/1)
      |> Enum.map(&parse_item(&1, context))

    character_spawners =
      Map.get(zone_data, "characters", [])
      |> Enum.filter(fn {_key, val} ->
        Map.has_key?(val, "spawn_rules")
      end)
      |> Enum.map(fn {key, val} ->
        {key, Map.fetch!(val, "spawn_rules")}
      end)
      |> Enum.map(&keys_to_atoms/1)
      |> Enum.map(&parse_spawner(&1, Map.put(context, :type, :character)))
      |> Enum.into(%{})

    characters =
      Map.get(zone_data, "characters", [])
      |> Enum.map(&keys_to_atoms/1)
      |> Enum.map(&parse_character(&1, context))

    %{
      zone
      | id: id,
        name: name,
        rooms: rooms,
        items: items,
        characters: characters,
        character_spawner: character_spawners,
        item_spawner: %{}
    }
  end

  defp parse_room({key, room}, context) do
    doors = Map.get(room, :doors, %{})
    id = World.parse_id(key)
    exit_context = %{doors: doors, room_id: id}

    exits =
      Map.get(room, :exits, [])
      |> Enum.map(&parse_exit(&1, exit_context))

    %Room{
      id: id,
      zone_id: context.zone_id,
      name: room.name,
      description: room.description,
      exits: exits,
      arena?: false,
      peaceful?: Map.get(room, :peaceful?, false),
      arena_data: nil
    }
  end

  defp parse_exit({key, room_exit}, context) do
    door = Map.get(context.doors, key)

    case room_exit do
      %{} ->
        %Exit{
          # TODO
        }

      to_room ->
        door = parse_door(door)
        type = if is_nil(door), do: :normal, else: :door

        %Exit{
          type: type,
          exit_name: key,
          start_room_id: context.room_id,
          end_room_id: to_room,
          hidden?: false,
          secret?: false,
          door: door
        }
    end
  end

  defp parse_door(door) do
    with %{} <- door do
      %Door{
        id: Map.fetch!(door, "id"),
        closed?: true,
        locked?: Map.has_key?(door, :key_id)
      }
    end
  end

  defp parse_verbs(verbs) do
    verbs
    |> Enum.map(&keys_to_atoms/1)
    |> Enum.map(fn {key, verb} ->
      {key, Map.put(verb, :key, key)}
    end)
    |> Enum.map(fn {key, verb} ->
      conditions = keys_to_atoms(verb.conditions)
      conditions = struct(Kalevala.Verb.Conditions, conditions)
      {key, Map.put(verb, :conditions, conditions)}
    end)
    |> Enum.map(fn {key, verb} ->
      {key, struct(Kalevala.Verb, verb)}
    end)
    |> Enum.into(%{})
  end

  defp parse_item({key, item}, context) do
    item_verbs =
      (get_verbs(item.type) ++ get_verbs(item.subtype))
      |> Enum.dedup()
      |> Enum.map(fn verb ->
        Map.get(context.verbs, verb)
      end)
      |> tap(fn x -> IO.inspect(x, label: "verbs") end)

    %Item{
      id: key,
      keywords: item.keywords,
      name: item.name,
      dropped_name: item.dropped_name,
      description: item.description,
      wear_slot: Map.get(item, :wear_slot),
      callback_module: Item,
      meta: %Mu.World.Item.Meta{
        container?: item.type == "container",
        contents: []
      },
      verbs: item_verbs
    }
  end

  defp get_verbs(type) do
    case type do
      "consumable" -> ~w(get drop)
      "equipment" -> ~w(get drop wear remove)
      "container" -> ~w(get_from put)
      _ -> []
    end
  end

  defp parse_spawner({key, spawner}, context) do
    id = "#{context.zone_id}:#{key}"

    spawner = %Spawner{
      prototype_id: id,
      active?: spawner.active?,
      type: context.type,
      rules: parse_spawn_rules(spawner, context)
    }

    {id, spawner}
  end

  defp parse_spawn_rules(rules, _context) do
    room_ids = rules.room_ids

    room_ids =
      case is_list(room_ids) do
        true -> room_ids
        false -> List.wrap(room_ids)
      end

    %SpawnRules{
      minimum_count: rules.minimum_count,
      maximum_count: rules.maximum_count,
      minimum_delay: rules.minimum_delay,
      random_delay: rules.random_delay,
      expires_in: Map.get(rules, :expires_in),
      room_ids: room_ids
    }
  end

  defp parse_character({key, character}, context) do
    initial_events = get_initial_events(character)

    mode =
      case Map.get(character, :sentinal?) != true do
        true -> :wander
        false -> :stay
      end

    %Character{
      id: "#{context.zone_id}:#{key}",
      name: character.name,
      description: character.description,
      meta: %Mu.Character.NonPlayerMeta{
        move_delay: Map.get(character, :move_delay, 60000),
        keywords: character.keywords,
        mode: mode,
        aggressive?: Map.get(character, :aggressive?, false),
        zone_id: context.zone_id,
        initial_events: parse_initial_events(initial_events, context)
      }
    }
  end

  defp get_initial_events(character) do
    initial_events = Map.get(character, :initial_events, [])

    case Map.get(character, :sentinal?) != true do
      true ->
        wander_event = %{
          "delay" => Map.get(character, :move_delay, 60000),
          "topic" => "npc/wander",
          "data" => %{}
        }

        initial_events ++ [wander_event]

      false ->
        initial_events
    end
  end

  defp parse_initial_events(initial_events, _context) do
    initial_events
    |> Enum.map(&keys_to_atoms/1)
    |> Enum.map(fn event_data ->
      data = Map.get(event_data, :data, %{})

      %Mu.Character.InitialEvent{
        delay: Map.get(event_data, :delay, 0),
        topic: event_data.topic,
        data: keys_to_atoms(data)
      }
    end)
  end

  defp parse_world(zones) do
    %World{zones: zones}
    |> split_out_rooms()
    |> split_out_items
    |> split_out_characters
  end

  defp split_out_rooms(world) do
    rooms =
      Enum.flat_map(world.zones, fn zone ->
        Map.get(zone, :rooms, [])
      end)

    %{world | rooms: rooms}
  end

  defp split_out_items(world) do
    items =
      Enum.flat_map(world.zones, fn zone ->
        Map.get(zone, :items, [])
      end)

    %{world | items: items}
  end

  defp split_out_characters(world) do
    characters =
      Enum.flat_map(world.zones, fn zone ->
        Map.get(zone, :characters, [])
      end)

    %{world | characters: characters}
  end

  defp keys_to_atoms(map = %{}) do
    Enum.into(map, %{}, fn {key, value} ->
      {String.to_atom(key), value}
    end)
  end

  defp keys_to_atoms({key, map = %{}}) do
    val =
      Enum.map(map, fn {key, value} ->
        {String.to_atom(key), value}
      end)
      |> Enum.into(%{})

    {key, val}
  end
end
