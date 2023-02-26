defmodule Mu.World.Zone.SpawnEvent do
  @moduledoc """
  Handles all the logic for spawning npcs or items into rooms.

  Event topics:
    - "init/..." - spawns all active prototypes in spawner up to minimum and schedules next
    - "activate/..." - activates a prototype
    - "deactive/..." - deactivates a prototype
    - "spawn/..." - spawns an instance of a prototype and schedules next
    - "despawn/..." - despawns one or more instance(s) of a prototype

  TODO:
    - Separate schedular into schedule_spawn() and schedule_despawn()
    - Add event to room to add item or character
  """
  import Kalevala.World.Zone.Context

  alias Mu.World.Zone.Spawner.InstanceTracking

  def call(context, event = %{topic: "init" <> type}) do
    spawner = get_spawner(context, event)
    spawn_fun = get_spawner_function(event)

    spawner.prototype_ids
    |> Enum.filter(fn prototype_id ->
      rules = spawner.rules[prototype_id]
      !is_nil(rules) and rules.active? and rules.minimum_count > 0
    end)
    |> Enum.reduce(context, fn {prototype_id, context} ->
      rules = spawner.rules[prototype_id]
      minimum_count = rules.minimum_count
      opts = [count: minimum_count, expires_in: rules.expires_in]

      context
      |> spawn_fun.(prototype_id, opts)
      |> schedule_spawn(minimum_count, rules, event)
    end)
  end

  def call(context, event = %{topic: "activate" <> _}) do
    spawner = get_spawner(context, event)
    prototype_id = event.data.prototype_id
    rules = spawner.rules[prototype_id]
    tracker = Map.get(spawner.instance_tracking, prototype_id, %InstanceTracking{})

    case !is_nil(rules) and !rules.active? do
      true ->
        rules = Map.put(rules, :active?, true)
        spawner = %{spawner | rules: Map.put(spawner.rules, prototype_id, rules)}
        type = get_spawner_key(event)
        context = put_data(context, type, spawner)
        instance_count = tracker.count

        case instance_count < rules.maximum_count and rules.minimum_count < instance_count do
          true ->
            spawn_fun = get_spawner_function(event)
            count = rules.minimum_count - instance_count

            context
            |> spawn_fun.(prototype_id, count: count, expires_in: rules.expires_in)
            |> schedule_spawn(instance_count + 1, rules, event)

          false ->
            context
        end

      false ->
        context
    end
  end

  def call(context, event = %{topic: "deactivate" <> _}) do
    spawner = get_spawner(context, event)
    prototype_id = event.data.prototype_id
    rules = spawner.rules[prototype_id]

    case !is_nil(rules) and rules.active? do
      true ->
        rules = Map.put(rules, :active?, false)
        spawner = %{spawner | rules: Map.put(spawner.rules, prototype_id, rules)}
        put_data(context, get_spawner_key(event), spawner)

      false ->
        context
    end
  end

  def call(context, event = %{topic: "spawn" <> _}) do
    spawner = get_spawner(context, event)
    prototype_id = event.data.prototype_id
    rules = spawner.rules[prototype_id]
    tracker = Map.get(spawner.instance_tracking, prototype_id, %InstanceTracking{})

    case !is_nil(rules) and rules.active? and tracker.count < rules.maximum_count do
      true ->
        spawn_fun = get_spawner_function(event)

        context
        |> spawn_fun.(prototype_id, expires_in: rules.expires_in)
        |> schedule_spawn(tracker.count + 1, rules, event)

      false ->
        context
    end
  end

  def call(context, event = %{topic: "despawn" <> type}) do
    spawner = get_spawner(context, event)
    prototype_id = event.data.prototype_id
    instance_id = event.data.instance_id
    tracker = Map.get(spawner.instance_tracking, prototype_id)

    case !is_nil(tracker) and tracker.count > 0 do
      true ->
        {[instance], instances} =
          Enum.split_with(tracker.instances, fn instance ->
            instance.id == instance_id
          end)

        tracker = %{tracker | count: tracker.count - 1, instances: instances}

        spawner = %{
          spawner
          | instance_tracking: Map.put(spawner.instance_tracking, prototype_id, tracker)
        }

        to_pid =
          case(type) do
            "/character" -> instance.pid
            "/item" -> instance.room_pid
          end

        context
        |> put_data(get_spawner_key(event), spawner)
        |> event(to_pid, self(), event.topic, event.data)

      false ->
        context
    end
  end

  defp get_spawner(context, %{topic: topic}) do
    cond do
      String.match?(topic, ~r/character/) -> context.data.character_spawner
      String.match?(topic, ~r/item/) -> context.data.item_spawner
    end
  end

  defp get_spawner_key(%{topic: topic}) do
    cond do
      String.match?(topic, ~r/character/) -> :character_spawner
      String.match?(topic, ~r/item/) -> :item_spawner
    end
  end

  defp get_spawner_type(%{topic: topic}) do
    cond do
      String.match?(topic, ~r/character/) -> "character"
      String.match?(topic, ~r/item/) -> "item"
    end
  end

  defp get_spawner_function(%{topic: topic}) do
    cond do
      String.match?(topic, ~r/character/) -> &spawn_characters/3
      String.match?(topic, ~r/item/) -> &spawn_items/3
    end
  end

  defp spawn_items(context, item_id, opts \\ []) do
    count = opts[:count] || 1

    Enum.reduce(1..count, context, fn {_, context} ->
      room_id = Enum.random(context.item_spawner.rules.room_ids)
      spawn_item(context, item_id, room_id)
    end)
  end

  defp spawn_item(context, item_id, room_id) do
    instance = %Kalevala.World.Item.Instance{
      id: Kalevala.World.Item.Instance.generate_id(),
      item_id: item_id,
      created_at: DateTime.utc_now(),
      meta: %Mu.World.Item.Meta{}
    }

    spawner = track_instance(context.data.item_spawner, item_id, instance)
    put_data(context, :character_spawner, spawner)
  end

  defp spawn_characters(context, character_id, opts \\ []) do
    count = opts[:count] || 1
    loadouts = opts[:loadouts]

    Enum.reduce(1..count, context, fn {_, context} ->
      room_id = Enum.random(context.data.spawner.rules.room_ids)

      loadout =
        case is_nil(loadouts) do
          true -> opts[:loadout] || []
          false -> Enum.random(loadouts)
        end

      spawn_character(context, character_id, room_id, loadout, opts[:expires_in])
    end)
  end

  defp spawn_character(context, character_id, room_id, loadout, expires_in) do
    character = prepare_character(character_id, room_id, loadout)

    config = [
      supervisor_name: CharacterSupervisor.global_name(character.meta.zone_id),
      communication_module: Mu.Communication,
      initial_controller: Mu.Character.NonPlayerController,
      quit_view: {Mu.Character.QuitView, "disconnected"}
    ]

    case Kalevala.World.start_character(character, config) do
      {:ok, pid} ->
        timestamp = DateTime.utc_now()

        instance = %Mu.Character.Instance{
          id: character.instance_id,
          character_id: character_id,
          pid: pid,
          created_at: timestamp,
          expires_at: expires_in && DateTime.add(timestamp, expires_in)
        }

        spawner = track_instance(context.data.character_spawner, character_id, instance)
        put_data(context, :character_spawner, spawner)

      _ ->
        Logger.error("Character #{character_id} failed to spawn.")
        context
    end
  end

  defp prepare_character(character_id, room_id, loadout) do
    character = Characters.get!(character_id)
    instance_id = "#{character_id}:#{Kalevala.Character.generate_id()}"
    loadout = loadout(character.inventory, loadout)
    %{character | id: instance_id, room_id: room_id, inventory: loadout}
  end

  defp loadout(base_loadout, override) do
    loadout = with [] <- override, do: base_loadout

    Enum.map(loadout, fn item_id ->
      %Kalevala.World.Item.Instance{
        id: Kalevala.World.Item.Instance.generate_id(),
        item_id: item_id,
        created_at: DateTime.utc_now(),
        meta: %Mu.World.Item.Meta{}
      }
    end)
  end

  defp schedule_spawn(context, count, rules, event) do
    delay = Enum.random(rules.minimum_delay..rules.random_delay)
    type = get_spawner_type(event.topic)

    case count < rules.maximum_count do
      true -> delay_event(context, delay, self(), "spawn/" <> type, event.data)
      false -> context
    end
  end

  defp scheduler(context, event) do
    spawner = get_spawner(context, event)
    prototype_id = event.data.prototype_id
    rules = spawner.rules[prototype_id]
    tracker = spawner.instance_tracking[prototype_id]
    type = get_spawner_type(event)
    delay = Enum.random(rules.minimum_delay..rules.maximum_delay)

    # schedule spawn
    context =
      case tracker.count < rules.maximum_count do
        true -> delay_event(context, delay, self(), "spawn/#{type}", event.data)
        false -> context
      end

    # schedule despawn
    expires_in = rules.expires_in

    case !is_nil(expires_in) do
      true -> delay_event(context, expires_in, self(), "despawn/#{to_string(type)}", event.data)
      false -> context
    end
  end

  defp track_instance(spawner, prototype_id, instance) do
    tracker = Map.get(spawner.instance_tracking, prototype_id, %InstanceTracking{})

    tracker = %{
      tracker
      | count: tracker.count + 1,
        instances: [instance | tracker.instances]
    }

    %{
      spawner
      | instance_tracking: Map.put(spawner.instance_tracking, prototype_id, tracker)
    }
  end
end
