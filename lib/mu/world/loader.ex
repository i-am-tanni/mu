defmodule Mu.World.Loader do
  alias Mu.World
  alias Mu.World.Zone
  alias Mu.World.Room
  alias Mu.World.Exit
  alias Mu.World.Exit.Door
  alias Mu.World.Item
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

    world_data = load_world(paths.world_path)

    context = %{
      verbs: parse_verbs(Jason.decode!(File.read!(paths.verbs_path))),
      brains: Mu.Brain.load_all()
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

  defp load_world(path) do
    load_folder(path)
    |> Enum.filter(fn file ->
      String.match?(file, ~r/\.json$/)
    end)
    |> Enum.map(&File.read!/1)
    |> Enum.map(&Jason.decode!/1)
    |> Enum.map(fn zone_data ->
      %{"zone" => %{"id" => id}} = zone_data
      {id, zone_data}
    end)
    |> Enum.into(%{})
  end

  defp load_folder(path, acc \\ []) do
    Enum.reduce(File.ls!(path), acc, fn file, acc ->
      path = Path.join(path, file)

      case String.match?(file, ~r/\./) do
        true -> [path | acc]
        false -> load_folder(path, acc)
      end
    end)
  end

  defp parse_zone({key, zone_data}, context) do
    zone = %Zone{}
    id = key
    %{"zone" => %{"name" => name}} = zone_data

    # prepare context
    context = Map.merge(context, %{zone_id: key})

    room_ids_by_mobile =
      for {room_id, room_data} <- Map.get(zone_data, "rooms", []),
          mobile_id <- Map.get(room_data, "mobiles", []),
          room_id = World.parse_id(room_id),
          reduce: %{} do
        acc -> Map.update(acc, mobile_id, [room_id], &[room_id | &1])
      end

    context = Map.put(context, :spawn_locations, room_ids_by_mobile)

    rooms =
      Map.get(zone_data, "rooms", [])
      |> Enum.map(&keys_to_atoms/1)
      |> Enum.map(&parse_room(&1, context))

    items =
      Map.get(zone_data, "items", [])
      |> Enum.map(&keys_to_atoms/1)
      |> Enum.map(&parse_item(&1, context))

    character_spawners =
      for {mobile_id, character} <- Map.get(zone_data, "characters", []),
          spawn_rules = character["spawn_rules"],
          is_map(spawn_rules),
          into: %{} do
        {mobile_id, spawn_rules}
        |> keys_to_atoms()
        |> parse_spawner(:character, context)
      end

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
        character_spawner: character_spawners
    }
  end

  defp parse_room({key, room}, context) do
    doors = Map.get(room, :doors, %{})
    id = World.parse_id(key)
    exit_context = %{doors: doors, room_id: id}

    exits =
      Map.get(room, :exits, [])
      |> Enum.map(&parse_exit(&1, exit_context))

    extra_descs =
      Map.get(room, :extra_descs, [])
      |> Enum.map(&parse_extra_desc/1)

    %Room{
      id: id,
      zone_id: context.zone_id,
      name: room.name,
      description: room.description,
      exits: exits,
      round_queue: [],
      next_round_queue: [],
      round_in_process?: false,
      extra_descs: extra_descs,
      item_templates: Map.get(room, :items, [])
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

  defp parse_extra_desc({keyword, data}) do
    %Room.ExtraDesc{
      keyword: keyword,
      description: data.description,
      hidden?: Map.get(data, :hidden) == true,
      highlight_color_override: Map.get(data, :highlight_color_override)
    }
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
    Enum.into(verbs, %{}, fn field = {key, _} ->
      {key, parse_verb(field)}
    end)
  end

  defp parse_verb({key, verb}) do
    conditions = Map.fetch!(verb, "conditions")
    conditions =
      %Kalevala.Verb.Conditions{
        location: conditions["location"]
      }

    %Kalevala.Verb{
      conditions: conditions,
      key: key,
      icon: verb["icon"],
      text: verb["text"]
    }
  end

  defp parse_item({key, item}, context) do
    item_verbs =
      (get_verbs(item.type) ++ get_verbs(item.subtype))
      |> Enum.dedup()
      |> Enum.map(&Map.fetch!(context.verbs, &1))
      
    %Item{
      id: key,
      keywords: item.keywords,
      name: item.name,
      dropped_name: item.dropped_name,
      description: item.description,
      wear_slot: Map.get(item, :wear_slot),
      callback_module: Item,
      type: item.type,
      subtype: item.subtype,
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

  defp parse_spawner({key, spawner}, type, context) do
    id = "#{context.zone_id}:#{key}"

    spawner = %Spawner{
      prototype_id: id,
      active?: spawner.active?,
      type: type,
      rules: parse_spawn_rules(spawner, key, context)
    }

    {id, spawner}
  end

  defp parse_spawn_rules(rules, mobile_template_id, context) do
    room_ids =
      case rules[:room_ids] || context.spawn_locations[mobile_template_id] do
        nil ->
          raise("No spawn locations found for #{mobile_template_id}")

        room_ids when is_list(room_ids) ->
          room_ids

        room_id ->
          List.wrap(room_id)
      end

    spawn_strategy =
      case Map.get(rules, :strategy) do
        "random" -> :random
        "round_robin" -> :round_robin
        nil -> :random
        strategy -> raise("Invalid strategy found: #{strategy}")
      end

    %SpawnRules{
      minimum_count: rules.minimum_count,
      maximum_count: rules.maximum_count,
      minimum_delay: rules.minimum_delay,
      random_delay: rules.random_delay,
      expires_in: Map.get(rules, :expires_in),
      room_ids: room_ids,
      strategy: spawn_strategy
    }
  end

  defp parse_character({key, character}, context) do
    initial_events = get_initial_events(character)

    flags = %Mu.Character.NonPlayerFlags{
      sentinel?: Map.get(character, :sentinel?) == true,
      pursuer?: true,
      aggressive?: Map.get(character, :aggressive?, false)
    }

    brains = context.brains

    brain =
      Map.get(brains, character[:brain])
      |> Mu.Brain.process(brains)

    %Character{
      id: "#{context.zone_id}:#{key}",
      name: character.name,
      description: character.description,
      brain: brain,
      meta: %Mu.Character.NonPlayerMeta{
        move_delay: Map.get(character, :move_delay, 60000),
        keywords: character.keywords,
        pose: :pos_standing,
        pronouns: Map.get(character, :pronouns, :female),
        zone_id: context.zone_id,
        initial_events: parse_initial_events(initial_events, context),
        in_combat?: false,
        flags: flags
      }
    }
  end

  defp get_initial_events(character) do
    Map.get(character, :initial_events, [])
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

  # atomizes keys of nested map
  defp keys_to_atoms({key, map}) when is_map(map) do
    val =
      Enum.into(map, %{}, fn {key, value} ->
        {String.to_atom(key), value}
      end)

    {key, val}
  end
end
