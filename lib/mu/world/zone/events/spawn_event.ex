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
    - Add event to room to add item or character
    - despawn public functions
    - schedule despawn implementation from spawn functions
  """
  import Kalevala.World.Zone.Context
  require Logger

  alias Kalevala.World.CharacterSupervisor
  alias Mu.World.Characters

  def call(context, event = %{topic: "init" <> _}) do
    get_spawners(context, event)
    |> Enum.filter(fn {_prototype_id, spawner} ->
      spawner.active? and spawner.rules.minimum_count > 0
    end)
    |> Enum.reduce(context, fn {_, spawner}, context ->
      context
      |> spawn_instances(spawner, spawner.rules.minimum_count)
      |> schedule_spawn(spawner)
    end)
  end

  def call(context, event = %{topic: "spawn" <> _}) do
    spawners = get_spawners(context, event)
    spawner = Map.fetch!(spawners, event.data.prototype_id)

    case spawner.active? and spawner.count < spawner.rules.maximum_count do
      true ->
        context
        |> spawn_instances(spawner)
        |> schedule_spawn(spawner)

      false ->
        context
    end
  end

  def call(context, event = %{topic: "despawn" <> _}) do
    spawners = get_spawners(context, event)
    spawner = Map.fetch!(spawners, event.data.prototype_id)
    instance_id = event.data.instance_id

    {[instance], instances} =
      Enum.split_with(spawner.instances, fn instance ->
        instance.id == instance_id
      end)

    spawner = Map.put(spawner, :instances, instances)

    context
    |> put_spawner(spawners, spawner)
    # |> despawn_instance(spawner, instance)
    |> schedule_spawn(spawner)
  end

  def call(context, event = %{topic: "activate" <> _}) do
    spawners = get_spawners(context, event)
    spawner = Map.fetch!(spawners, event.data.prototype_id)

    case !spawner.rules.active? do
      true ->
        spawner = %{spawner | active?: true}

        context
        |> put_spawner(spawners, spawner)
        |> schedule_spawn(spawner)

      false ->
        context
    end
  end

  def call(context, event = %{topic: "deactivate" <> _}) do
    spawners = get_spawners(context, event)
    spawner = Map.fetch!(spawners, event.data.prototype_id)

    case spawner.rules.active? do
      true -> put_spawner(context, spawners, %{spawner | active?: false})
      false -> context
    end
  end

  defp get_spawners(context, %{topic: topic}) do
    cond do
      String.match?(topic, ~r/character/) -> context.data.character_spawner
      String.match?(topic, ~r/item/) -> context.data.item_spawner
    end
  end

  defp put_spawner(context, spawners, spawner) do
    spawners = %{spawners | spawner.prototype_id => spawner}

    spawner_type =
      case spawner.type do
        :character -> :character_spawner
        :item -> :item_spawner
      end

    put_data(context, spawner_type, spawners)
  end

  defp spawn_instances(context, spawner, count \\ 1) do
    %{type: type, prototype_id: prototype_id, rules: rules} = spawner

    Enum.reduce(1..count, context, fn _, context ->
      room_id = Enum.random(rules.room_ids)

      case type do
        :character -> spawn_character(context, prototype_id, room_id, [], rules.expires_in)
        :item -> spawn_item(context, prototype_id, room_id)
      end
    end)
  end

  defp spawn_item(context, item_id, room_id) do
    instance = %Kalevala.World.Item.Instance{
      id: Kalevala.World.Item.Instance.generate_id(),
      item_id: item_id,
      created_at: DateTime.utc_now(),
      meta: %Mu.World.Item.Meta{}
    }

    spawners = context.data.item_spawner
    spawner = Map.fetch!(spawners, item_id)
    spawner = %{spawner | count: spawner.count + 1, instances: [instance | spawner.instances]}

    put_spawner(context, spawners, spawner)
  end

  defp spawn_character(context, character_id, room_id, loadout, _expires_in) do
    character = prepare_character(character_id, room_id, loadout)

    config = [
      supervisor_name: CharacterSupervisor.global_name(character.meta.zone_id),
      communication_module: Mu.Communication,
      initial_controller: Mu.Character.SpawnController,
      quit_view: {Mu.Character.QuitView, "disconnected"}
    ]

    case Kalevala.World.start_character(character, config) do
      {:ok, _} ->
        timestamp = DateTime.utc_now()

        instance = %Mu.Character.Instance{
          id: character.id,
          character_id: character_id,
          created_at: timestamp
          # TODO: consider expires_at units
          # expires_at: expires_in && DateTime.add(timestamp, expires_in)
        }

        spawners = context.data.character_spawner
        spawner = Map.fetch!(spawners, character_id)
        spawner = %{spawner | count: spawner.count + 1, instances: [instance | spawner.instances]}

        put_spawner(context, spawners, spawner)

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

  defp schedule_spawn(context, spawner) do
    case spawner.count < spawner.rules.maximum_count do
      true ->
        %{minimum_delay: minimum_delay, random_delay: random_delay} = spawner.rules
        delay = Enum.random(minimum_delay..random_delay)
        data = %{prototype_id: spawner.prototype_id}
        delay_event(context, delay, self(), "spawn/" <> to_string(spawner.type), data)

      false ->
        context
    end
  end
end
