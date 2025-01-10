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

  alias Mu.World.Kickoff
  alias Mu.World.NonPlayers


  def call(context, event = %{topic: "init" <> _}) do
    spawner_type = spawner_type(event)
    spawners = Map.get(context.data, spawner_type)

    # spawn minimum number of instances for active spawners
    updates =
      for {_, spawner} <- spawners,
          minimum_count = spawner.rules.minimum_count,
          spawner.active? and minimum_count > 0 do
        spawn_instances(spawner, minimum_count)
      end

    spawners =
      Enum.reduce(updates, spawners, fn spawner, acc ->
        Map.put(acc, spawner.prototype_id, spawner)
      end)

    updates
    |> Enum.reduce(context, &schedule_spawn(&2, &1))
    |> put_data(spawner_type, spawners)
  end

  def call(context, event = %{topic: "spawn" <> _}) do
    spawner_type = spawner_type(event)
    spawners = Map.get(context.data, spawner_type)
    prototype_id = event.data.prototype_id
    spawner = Map.fetch!(spawners, prototype_id)

    case spawner.active? and spawner.count < spawner.rules.maximum_count do
      true ->
        spawner = spawn_instances(spawner, 1)
        spawners = Map.put(spawners, prototype_id, spawner)

        context
        |> put_data(spawner_type, spawners)
        |> schedule_spawn(spawner)

      false ->
        context
    end
  end

  def call(context, event = %{topic: "despawn" <> _}) do
    spawner_type = spawner_type(event)
    spawners = Map.get(context.data, spawner_type)
    spawner = Map.fetch!(spawners, event.data.prototype_id)
    instance_id = event.data.instance_id

    instances = Enum.reject(spawner.instances, &(&1.id == instance_id))
    spawner = Map.put(spawner, :instances, instances)
    spawners = Map.put(spawners, spawner.prototype_id, spawner)

    context
    |> put_data(spawner_type, spawners)
    # |> despawn_instance(spawner, instance)
    |> schedule_spawn(spawner)
  end

  def call(context, event = %{topic: "activate" <> _}) do
    spawner_type = spawner_type(event)
    spawners = Map.get(context.data, spawner_type)
    spawner = Map.fetch!(spawners, event.data.prototype_id)

    case !spawner.rules.active? do
      true ->
        spawner = %{spawner | active?: true}
        spawner =
          case Map.get(event.data, :spawn_minimum?) == true do
            true -> spawn_instances(spawner, spawner.rules.minimum_count)
            false -> spawner
          end

        spawners = Map.put(spawners, spawner.prototype_id, spawner)

        context
        |> put_data(spawner_type, spawners)
        |> schedule_spawn(spawner)

      false ->
        context
    end
  end

  def call(context, event = %{topic: "deactivate" <> _}) do
    spawner_type = spawner_type(event)
    spawners = Map.get(context.data, spawner_type)
    spawner = Map.fetch!(spawners, event.data.prototype_id)

    case spawner.rules.active? do
      true ->
        spawner = %{spawner | active?: false}
        spawners = Map.put(spawners, spawner.prototype_id, spawner)
        put_data(context, spawner_type, spawners)

      false ->
        context
    end
  end

  # private functions

  defp spawn_instances(spawner, count, opts \\ []) do
    Enum.reduce(1..count, spawner, fn _, acc ->
      {room_id, updated_acc} = get_room_id(acc)
      spawn_instance(updated_acc, room_id, opts)
    end)
  end

  defp spawn_instance(spawner, room_id, opts) when spawner.type == :character do
    loadout_override = Keyword.get(opts, :loadout, [])
    character = prepare_character(spawner.prototype_id, room_id, loadout_override)

    case Kickoff.spawn_mobile(character) do
      {:ok, instance_id} ->
        timestamp = DateTime.utc_now()

        instance = %Mu.Character.Instance{
          id: spawner.prototype_id,
          character_id: instance_id,
          created_at: timestamp
          # TODO: consider expires_at field
          # expires_at: expires_in && DateTime.add(timestamp, expires_in)
        }

        instances = [instance | spawner.instances]

        %{spawner | count: spawner.count + 1, instances: instances}

      {:error, :spawn_failed} ->
        Logger.error("Character #{spawner.prototype_id} failed to spawn.")
        spawner
    end
  end

  defp spawn_instance(spawner, _room_id, _opts) when spawner.type == :item do
    instance = build_item_instance(spawner.prototype_id)
    %{spawner | count: spawner.count + 1, instances: [instance | spawner.instances]}
  end

  # item spawning functions

  defp build_item_instance(item_id) do
    item = Mu.World.Items.get!(item_id)
    meta = item.meta

    %Kalevala.World.Item.Instance{
      id: Kalevala.World.Item.Instance.generate_id(),
      item_id: item_id,
      created_at: DateTime.utc_now(),
      meta: %{meta | contents: build_container_contents(meta)}
    }
  end

  defp build_container_contents(meta) do
    case meta.container? do
      true ->
        Enum.map(meta.contents, fn item_id ->
          build_item_instance(item_id)
        end)

      false ->
        []
    end
  end

  # character spawning functions

  defp prepare_character(character_id, room_id, loadout_override) do
    character = NonPlayers.get!(character_id)
    loadout = loadout(character.inventory, loadout_override)
    %{character | room_id: room_id, inventory: loadout}
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

  # misc helper functions

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

  defp get_room_id(spawner) when spawner.rules.strategy == :random do
    {Enum.random(spawner.rules.room_ids), spawner}
  end

  defp get_room_id(spawner = %{rules: rules}) when rules.strategy == :round_robin do
    {room_id, round_robin_tail} =
      case {rules.room_ids, rules.round_robin_tail} do
        # if cycle is complete, start a new cycle from room_id list
        {[h | t], []} -> {h, t}
        # or simply advance cycle
        {_, [h | t]} -> {h, t}
      end

   rules = %{rules | round_robin_tail: round_robin_tail}
   spawner = %{spawner | rules: rules}
   {room_id, spawner}
  end

  defp spawner_type(_event = %{topic: topic}) do
    cond do
      String.match?(topic, ~r/character/) -> :character_spawner
      String.match?(topic, ~r/item/) -> :item_spawner
    end
  end

end
