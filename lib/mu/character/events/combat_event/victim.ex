defmodule Mu.Character.CombatEvent.Victim.Request do
  use Kalevala.Character.Event

  alias Mu.Character.CombatCommit

  def process(conn, %{data: data}) do
    # stats = conn.character.meta.stats
    hitroll = data.hitroll

    amount =
      data.damages
      |> Enum.map(&calc_damage(&1, hitroll, %{}))
      |> Enum.sum()

    %CombatCommit{
      attacker: data.attacker,
      victim: character(conn),
      verb: data.verb,
      damage: amount,
      effects: data.effects
    }
  end

  defp calc_damage(damage, hitroll, _stats) do
    attacker_dam_type = damage.type
    hit? = hitroll > Enum.random(1..4)

    case hit? do
      true ->
        case physical?(attacker_dam_type) do
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
  use Kalevala.Character.Event
  import Mu.Utility

  alias Mu.Character.Threat

  @threat_expires_in 3

  def update(conn, event) do
    conn
    |> update_hp(event)
    |> update_threat(event)
  end

  defp update_hp(conn, event) do
    damage = event.data.damage
    vitals = conn.character.meta.vitals
    vitals = %{vitals | health_points: vitals.health_points - damage}

    conn
    |> put_meta(:vitals, vitals)
    |> then_if(vitals < 0, fn conn ->
      data = Map.take(event.data, [:attacker, :victim])
      data = Map.put(data, :death_cry, "shrieks in agony")
      event(conn, "char/death", data)
    end)
  end

  defp update_threat(conn, event) do
    threat_table = get_meta(conn, :threat_table)

    threat_table =
      Enum.reject(threat_table, fn {_, %{expires_at: expires_at}} ->
        Time.compare(Time.utc_now(), expires_at) == :gt
      end)
      |> Enum.into(%{})

    attacker = event.data.attacker
    attacker_id = attacker.id

    threat =
      Map.get(
        threat_table,
        attacker_id,
        struct(Threat, id: attacker_id, character: attacker, value: 0)
      )

    threat = %{
      threat
      | value: threat.value + event.data.damage,
        expires_at: Time.add(Time.utc_now(), @threat_expires_in, :minute)
    }

    threat_table = Map.put(threat_table, attacker_id, threat)

    target = update_target(conn, event, threat_table)

    conn
    |> put_meta(:target, target)
    |> put_meta(:threat_table, threat_table)
  end

  defp update_target(conn, event, threat_table) do
    target = get_meta(conn, :target)
    attacker = event.data.attacker
    attacker_id = attacker.id

    case !is_nil(target) and target.id != attacker_id and damage_percent(conn, event) < 0.25 do
      true ->
        sorted =
          threat_table
          |> Map.values()
          |> Enum.sort(&(&1.value > &2.value))

        case Enum.take(sorted, 2) do
          [%{id: ^attacker_id, value: threat1}, %{value: threat2}] when threat1 > threat2 * 1.5 ->
            attacker

          _ ->
            target
        end

      false ->
        attacker
    end
  end

  defp damage_percent(conn, event) do
    event.data.damage / conn.character.meta.vitals.max_health_points
  end
end

defmodule Mu.Character.CombatEvent.Victim do
  use Kalevala.Character.Event

  alias __MODULE__.Request
  alias __MODULE__.Commit
  alias Mu.Character

  def request(conn, event) do
    case consider(conn, event) do
      :ok ->
        data = Request.process(conn, event)
        event(conn, commit_topic(conn, event), data)

      {:error, reason} ->
        event(conn, "combat/abort", %{reason: reason})
    end
  end

  def kickoff(conn, event) do
    case get_meta(conn, :mode) != :combat do
      true ->
        conn
        |> put_meta(:target, event.data.attacker)
        |> put_meta(:mode, :combat)

      false ->
        conn
    end
  end

  def update(conn, event), do: Commit.update(conn, event)

  defp consider(conn, event) do
    :ok
  end

  defp commit_topic(conn, event) do
    cond do
      event.topic == "round/request" ->
        "round/commit"

      Character.in_combat?(conn) and event.data.attacker.meta.mode == :combat ->
        "combat/commit"

      true ->
        "combat/kickoff"
    end
  end
end
