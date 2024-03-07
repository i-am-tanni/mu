defmodule Mu.Character.CombatEvent.Victim.Request do
  use Kalevala.Character.Event

  alias Mu.Character.CombatCommit
  alias Mu.Character

  def build_commit_data(conn, %{data: data}) do
    # stats = conn.character.meta.stats
    hitroll = data.hitroll

    damage =
      data.damages
      |> Enum.map(&calc_damage(&1, hitroll, %{}))
      |> Enum.sum()

    character = character(conn, trim: true)
    vitals = character.meta.vitals
    vitals = %{vitals | health_points: vitals.health_points - damage}
    meta = %{character.meta | vitals: vitals}
    character = %{character | meta: meta}

    %CombatCommit{
      round_based?: data.round_based?,
      attacker: data.attacker,
      victim: character,
      verb: data.verb,
      damage: damage,
      effects: data.effects
    }
  end

  # private

  defp calc_damage(damage, hitroll, _stats) do
    dam_type = damage.type
    hit? = hitroll > Enum.random(1..4)

    case hit? do
      true ->
        case physical?(dam_type) do
          true ->
            damage = damage.damroll
            max_protection = 4
            min_protection = div(max_protection, 2)
            max(0, damage - Enum.random(min_protection..max_protection))

          false ->
            damage.damroll
        end

      false ->
        0
    end
  end

  defp physical?(dam_type), do: dam_type in [:blunt, :pierce, :slash]

  defp damage(damroll, stats, attacker_dam_type) do
    weapon_triangle_mod =
      case {stats.dam_type, attacker_dam_type} do
        {:blunt, :slash} -> 0.7
        {:slash, :pierce} -> 0.7
        {:pierce, :blunt} -> 0.7
        {:blunt, :pierce} -> 1.3
        {:slash, :blunt} -> 1.3
        {:pierce, :slash} -> 1.3
        {_, _} -> 1
      end

    damroll * weapon_triangle_mod
  end

  def evasion(stats, attacker_dam_type) do
    weapon_triangle_mod =
      case {stats.dam_type, attacker_dam_type} do
        {:blunt, :slash} -> 1.3
        {:slash, :pierce} -> 1.3
        {:pierce, :blunt} -> 1.3
        {:blunt, :pierce} -> 0.7
        {:slash, :blunt} -> 0.7
        {:pierce, :slash} -> 0.7
        {_, _} -> 1
      end

    round((stats.base_evasion + stats.bonus_evasion) * weapon_triangle_mod)
  end

  def protection(conn, stats) do
    stats.base_protection + stats.bonus_protection
  end
end

defmodule Mu.Character.CombatEvent.Victim.Commit do
  @moduledoc """
  Commit an approved combat request as the victim.
  Commit occurs immediately after approval then is dispatched back to the room to notify attacker / witnesses.

  Update vitals, handle the victim's death, update the victim's threat table, etc.
  """

  use Kalevala.Character.Event
  import Mu.Character.Guards

  alias Mu.Character.Threat

  @threat_expires_in 3

  def update(conn, event) do
    # this was originally broken out into multiple functions
    # but combined into one for readability so that it flows linearly

    # update vitals and check for death
    %{vitals: vitals} = event.data.victim.meta

    conn = put_meta(conn, :vitals, vitals)

    case vitals.health_points > 1 do
      true ->
        # update threat table and target
        threat_table = get_meta(conn, :threat_table)

        threat_table =
          Enum.filter(threat_table, fn {_, %{expires_at: expires_at}} ->
            Time.compare(Time.utc_now(), expires_at) == :lt
          end)
          |> Enum.into(%{})

        attacker = event.data.attacker
        attacker_id = attacker.id
        threat = update_threat(conn, event, threat_table, attacker_id)
        threat_table = Map.put(threat_table, attacker_id, threat)
        target = get_meta(conn, :target)
        target = update_target(conn, event, threat_table, target, attacker)

        conn
        |> put_meta(:threat_table, threat_table)
        |> put_meta(:target, target)

      false ->
        data = Map.take(event.data, [:attacker, :victim])
        data = Map.put(data, :death_cry, "shrieks in agony")
        event(conn, "death", data)
    end
  end

  # private

  defp update_threat(conn, event, threat_table, attacker_id) do
    target = get_meta(conn, :target)
    %{attacker: attacker, damage: damage} = event.data

    threat =
      case target.id == attacker_id do
        true ->
          Map.get(
            threat_table,
            attacker_id,
            struct(Threat, id: attacker_id, character: target, value: 0)
          )

        false ->
          Map.get(
            threat_table,
            attacker_id,
            struct(Threat, id: attacker_id, character: attacker, value: 0)
          )
      end

    %{
      threat
      | value: threat.value + damage,
        expires_at: Time.add(Time.utc_now(), @threat_expires_in, :minute)
    }
  end

  defp update_target(_, _, _, target, attacker) when target.id == attacker.id, do: target

  defp update_target(conn, event, threat_table, target, attacker) do
    attacker_id = attacker.id

    case damage_percent(conn, event) < 0.25 do
      true ->
        # Change to attacker_id if threat is significantly the highest
        sorted =
          threat_table
          |> Map.values()
          |> Enum.sort(&(&1.value > &2.value))

        case Enum.take(sorted, 2) do
          [%{id: ^attacker_id, value: threat1}, %{value: threat2}]
          when threat1 > threat2 * 1.5 ->
            attacker

          _ ->
            target
        end

      false ->
        attacker
    end
  end

  defp damage_percent(conn, event) do
    %{max_health_points: max_health_points} = get_meta(conn, :vitals)
    event.data.damage / max_health_points
  end
end

defmodule Mu.Character.CombatEvent.Victim do
  use Kalevala.Character.Event
  import Mu.Character.Guards

  alias __MODULE__.Request
  alias __MODULE__.Commit
  alias Mu.Character

  def request(conn, event) do
    case consider(conn, event) do
      :ok ->
        data = Request.build_commit_data(conn, event)
        topic = commit_topic(conn, event)

        conn
        |> event(topic, data)
        |> reroute(topic, data)

      {:error, reason} ->
        event(conn, "combat/abort", %{reason: reason})
    end
  end

  # Victim commits immediately (does not wait for forwarding event) to prevent race conditions
  # Race conditions can occur if an event is received between the request and the commit
  # Because the commit is material to consideration of any subsequent event, it should record immediately

  defp reroute(conn, topic, data) do
    event = %Kalevala.Event{
      topic: topic,
      data: data,
      from_pid: self()
    }

    # Must reroute event because this will trigger the change to combat state if kickoff
    conn.controller.event(conn, event)
  end

  defdelegate update(conn, event), to: Commit

  defp consider(conn, _event) do
    cond do
      is_pathing(conn) -> {:error, "forbidden"}
      true -> :ok
    end
  end

  defp commit_topic(conn, event) do
    case Character.in_combat?(conn) and Character.in_combat?(event.data.attacker) do
      true -> "combat/commit"
      false -> "combat/kickoff"
    end
  end
end
