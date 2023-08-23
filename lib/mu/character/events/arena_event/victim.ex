defmodule Mu.Character.ArenaEvent.Victim do
  @moduledoc """
  Combat events related recipients of combat actions (healing, damage, etc.)
  """

  use Kalevala.Character.Event
  import Mu.Character.CombatFlash

  alias Mu.World.Arena.Damage

  @doc """
  A turn request is received by the victim from the attacker for the victim's approval or rejection.
  If approved, victim processes turn outcome.
  """
  def request(conn, event) do
    data = calc_damage(conn, event)

    event(conn, "turn/commit", data)
  end

  @doc """
  Once a turn commit is received, update the victim
  """
  def update(conn, event) do
    conn
    |> update_hp(event)
    |> update_threat(event)
  end

  # If victim approves turn, victim processes outcome.
  # I.e. roll for hit and net any damage against damage reduction / resistances

  defp calc_damage(_conn, event) do
    data = event.data

    total_damage =
      Enum.reduce(data.effects, 0, fn
        %Damage{amount: amount}, acc -> acc + amount
        _, acc -> acc
      end)

    Map.put(data, :total_damage, total_damage)
  end

  defp update_hp(conn, event) when event.data.total_damage > 0 do
    total_damage = event.data.total_damage
    vitals = conn.character.meta.vitals
    vitals = %{vitals | health_points: vitals.health_points - total_damage}

    case vitals.health_points > 0 do
      true ->
        conn

      false ->
        conn
        |> event("character/death", event.data)
    end
  end

  defp update_hp(conn, _event), do: conn

  defp update_threat(conn, event) do
    threat_table = get_combat_flash(conn, :threat_table)
    max_hp = conn.character.meta.vitals.max_health_points

    total_damage = event.data.total_damage

    id = event.data.attacker.id
    threat = total_damage / max_hp * 1000
    threat = threat + Map.get(threat_table, id, 0)
    threat_table = Map.put(threat_table, id, threat)
    put_combat_flash(conn, :threat_table, threat_table)
  end
end
