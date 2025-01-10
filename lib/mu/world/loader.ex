defmodule Mu.World.Loader do
  alias Mu.World
  alias Mu.World.Zone
  alias Mu.World.Room
  alias Mu.World.Exit
  alias Mu.World.Exits
  alias Mu.World.Exit.Door
  alias Mu.World.Item
  alias Kalevala.Character
  alias Mu.World.Zone.Spawner.SpawnRules
  alias Mu.World.Zone.Spawner
  alias Mu.World.RoomIds

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
    for file <- load_folder(path),
        String.match?(file, ~r/\.json$/),
        zone_data = Jason.decode!(File.read!(file)),
        %{"zone" => %{"id" => zone_id}} = zone_data,
        into: %{} do
      {zone_id, zone_data}
    end
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

  defp parse_zone({zone_id, zone_data}, context) do
    %{"zone" => %{"name" => name}} = zone_data

    rooms =
      Map.get(zone_data, "rooms", [])
      |> Enum.map(fn {local_id, room_data} ->
        room_id = RoomIds.get!("#{zone_id}.#{local_id}")
        room_data = Map.put(room_data, "template_id", local_id)
        {room_id, room_data}
      end)

    # prepare context
    context = Map.merge(context, %{zone_id: zone_id})

    room_ids_by_mobile =
      for {room_id, room_data} <- rooms,
          mobile_id <- Map.get(room_data, "mobiles", []),
          reduce: %{} do
        acc -> Map.update(acc, mobile_id, [room_id], &[room_id | &1])
      end

    context = Map.put(context, :spawn_locations, room_ids_by_mobile)

    rooms =
      rooms
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

    %Zone{
      id: zone_id,
      name: name,
      rooms: rooms,
      items: items,
      characters: characters,
      character_spawner: character_spawners
    }
  end

  defp parse_room({key, room}, context) do
    doors = Map.get(room, :doors, %{})
    exit_context = %{doors: doors, room_id: key, zone_id: context.zone_id}

    exits =
      Map.get(room, :exits, [])
      |> Enum.map(&parse_exit(&1, exit_context))
      |> Exits.sort()

    extra_descs =
      Map.get(room, :extra_descs, [])
      |> Enum.map(&parse_extra_desc/1)

    %Room{
      id: key,
      template_id: room.template_id,
      zone_id: context.zone_id,
      name: room.name,
      x: room.x,
      y: room.y,
      z: room.z,
      symbol: room.symbol,
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
    to_room =
      case is_binary(room_exit) and String.match?(room_exit, ~r/([^\.]+)\.([^\.]+)/) do
        true ->
          # if '.' separator is found in room_exit name, assume this is in "ZoneId.room_id" format
          RoomIds.get!(room_exit)

        false ->
          # else, assume this exit refers to a local id, so combine with current zone id
          RoomIds.get!("#{context.zone_id}.#{room_exit}")
      end

    door = parse_door(context.doors[key])

    type =
      cond do
        door -> :door
        true -> :normal
      end

    %Exit{
      type: type,
      exit_name: key,
      start_room_id: context.room_id,
      end_room_id: to_room,
      end_template_id: room_exit,
      hidden?: false,
      secret?: false,
      door: door
    }
  end

  defp parse_extra_desc({keyword, data}) do
    %Room.ExtraDesc{
      keyword: keyword,
      description: data.description,
      hidden?: Map.get(data, :hidden) == true,
      color_override: Map.get(data, :color_override)
    }
  end

  defp parse_door(door) do
    with %{"id" => id} <- door do
      %Door{
        id: id,
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
      zone_id: context.zone_id,
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
    zone_id = context.zone_id

    spawner =
      with %{room_ids: room_ids} <- spawner do
        room_ids =
          Enum.map(room_ids, fn local_id ->
            RoomIds.get!("#{zone_id}.#{local_id}")
          end)

        %{spawner | room_ids: room_ids}
      end

    id = "#{zone_id}.#{key}"

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
      case Map.get(rules, :rooms, context.spawn_locations[mobile_template_id]) do
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
      case Map.get(character, :brain) do
        "brain_not_loaded" ->
          %Mu.Brain{
            id: :brain_not_loaded,
            root: %Kalevala.Brain.NullNode{}
          }

        brain_id ->
          Map.get(brains, brain_id)
          |> Mu.Brain.process(brain_id, brains)
      end


    %Character{
      id: "#{context.zone_id}.#{key}",
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

  defp keys_to_atoms(map) when is_map(map) do
    Enum.into(map, %{}, fn {key, value} ->
      {String.to_atom(key), value}
    end)
  end

  # atomizes keys of nested map
  defp keys_to_atoms({key, map}) when is_map(map) do
    map = keys_to_atoms(map)
    {key, map}
  end
end
