defmodule Mu.World.Zone.Spawner.Rules do
  defstruct [
    :active?,
    :minimum_count,
    :maximum_count,
    :minimum_delay,
    :random_delay,
    :expires_in,
    :room_ids
  ]
end

defmodule Mu.World.Zone.Spawner.InstanceTracking do
  defstruct instances: [], count: 0
end

defmodule Mu.World.Zone.Spawner do
  alias Mu.World.Characters
  alias Mu.World.Zone.Spawner.InstanceTracking
  alias Kalevala.World.CharacterSupervisor

  require Logger
  defstruct [:instance_ids, instance_tracking: %{}, rules: %{}]

  def spawn_character(spawner, character_id, room_id, loadout) do
    character = Characters.get!(character_id)
    instance_id = "#{character_id}:#{Kalevala.Character.generate_id()}"
    loadout = with [] <- loadout, do: character.inventory

    loadout =
      Enum.map(loadout, fn item_id ->
        %Kalevala.World.Item.Instance{
          id: Kalevala.World.Item.Instance.generate_id(),
          item_id: item_id,
          created_at: DateTime.utc_now(),
          meta: %Mu.World.Item.Meta{}
        }
      end)

    character = %{character | id: instance_id, room_id: room_id, inventory: loadout}

    config = [
      supervisor_name: CharacterSupervisor.global_name(character.meta.zone_id),
      communication_module: Mu.Communication,
      initial_controller: Mu.Character.NonPlayerController,
      quit_view: {Mu.Character.QuitView, "disconnected"}
    ]

    case Kalevala.World.start_character(character, config) do
      {:ok, pid} ->
        instance = %Mu.Character.Instance{
          id: instance_id,
          character_id: character_id,
          pid: pid,
          created_at: DateTime.utc_now()
        }

        tracker = Map.get(spawner.instance_tracking, character_id, %InstanceTracking{})

        tracker = %{
          tracker
          | count: tracker.count + 1,
            instances: [instance | tracker.instances]
        }

        %{spawner | instance_tracking: Map.put(spawner.instance_tracking, character_id, tracker)}

      _ ->
        Logger.error("Character #{character_id} failed to spawn.")
        spawner
    end
  end
end
