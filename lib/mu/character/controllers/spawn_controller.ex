defmodule Mu.Character.SpawnController do
  use Kalevala.Character.Controller
  require Logger

  alias Kalevala.World.CharacterSupervisor
  alias Mu.World.NonPlayerCharacters
  alias Mu.Character.Spawner.SpawnData

  @impl true
  def init(conn) do
    data = conn.character.meta

    Enum.reduce(data.prototype_ids, conn, fn {prototype_id, conn} ->
      rules = data.rules[prototype_id]
      minimum_count = rules.minimum_count

      case !is_nil(rules) and minimum_count > 0 do
        true ->
          conn = spawn_instances(conn, prototype_id, minimum_count, rules.room_ids)

          case minimum_count < rules.maximum_count do
            true ->
              delay = Enum.random(rules.minimum_delay..rules.random_delay)
              delay_event(conn, delay, "spawn", prototype_id)

            false ->
              conn
          end

        false ->
          conn
      end
    end)
  end

  defp spawn_instances(conn, prototype_id, count, room_ids) do
    Enum.reduce(1..count, conn, fn {_, conn} ->
      spawn_instance(conn, prototype_id, Enum.random(room_ids))
    end)
  end

  defp spawn_instance(conn, prototype_id, room_id) do
    case conn.character.meta.type do
      :character -> spawn_character(conn, prototype_id, room_id)
    end
  end

  defp spawn_character(conn, character_id, room_id) do
    character = NonPlayerCharacters.get!(character_id)
    instance_id = "#{character_id}:#{Kalevala.Character.generate_id()}"
    character = %{character | id: instance_id, room_id: room_id}

    config = [
      supervisor_name: CharacterSupervisor.global_name(character.meta.zone_id),
      communication_module: Mu.Communication,
      initial_controller: Mu.Character.NonPlayerController,
      quit_view: {Mu.Character.QuitView, "disconnected"}
    ]

    case Kalevala.World.start_character(character, config) do
      {:ok, pid} ->
        data = conn.character.meta

        instance = %Mu.Character.Instance{
          id: instance_id,
          character_id: character_id,
          pid: pid,
          created_at: DateTime.utc_now()
        }

        spawn_data = Map.get(data.spawns, character_id, %SpawnData{})

        spawn_data = %{
          spawn_data
          | count: spawn_data.count + 1,
            instances: [instance | spawn_data.instances]
        }

        put_meta(conn, :spawns, Map.put(data.spawns, character_id, spawn_data))

      {:error, _} ->
        Logger.error("Character #{character_id} failed to spawn.")
        conn
    end
  end

  def despawn_instance(conn, prototype_id) do
    spawn_data = get_meta(conn, :spawns)
    instance_data = spawn_data[prototype_id]

    case !is_nil(instance_data) do
      true ->
        instances =
          Enum.reject(instance_data.instances, fn instance ->
            instance.id == prototype_id
          end)

        instance_data = %{instance_data | count: instance_data.count - 1, instances: instances}
        spawn_data = %{spawn_data | prototype_id => instance_data}
        put_meta(conn, :spawns, spawn_data)

      false ->
        conn
    end
  end
end
