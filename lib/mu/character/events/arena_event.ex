defmodule Mu.Character.ArenaEvent do
  @moduledoc """
  Events for in-progress combat events that occur in the instanced arena.
  For initiating combat, see CombatEvent.
  """

  use Kalevala.Character.Event
  import Mu.Character.CombatFlash

  alias Mu.World.Arena.Damage
  alias Mu.Character.ArenaView
  alias Mu.Character.CommandView

  @doc """
  A turn notificiation is received from the arena when it is your turn.
  """
  def notify(conn, event) do
    turn_queue = get_combat_flash(conn, :turn_queue)

    case turn_queue do
      [[] | turn_queue] ->
        conn
        |> put_combat_flash(:turn_queue, turn_queue)
        |> notify(event)

      [sequence | turn_queue] when is_list(sequence) ->
        [turn | rest] = sequence

        conn
        |> put_combat_flash(:turn_queue, [rest | turn_queue])
        |> put_combat_flash(:turn_requested?, true)
        |> event("turn/request", %{turn: turn})

      [turn | turn_queue] ->
        conn
        |> put_combat_flash(:turn_queue, turn_queue)
        |> put_combat_flash(:turn_requested?, true)
        |> event("turn/request", %{turn: turn})

      [] ->
        put_combat_flash(conn, :on_turn?, true)
    end
  end

  @doc """
  A turn request is received by the victim from the attacker for their approval or rejection.
  If approved, victim processes turn outcome.
  """
  def request(conn, event) do
    data = calc_damage(conn, event)

    event(conn, "turn/commit", data)
  end

  @doc """
  A committed turn is received by all participants in the room.
  The commited turn is the outcome as decided by both attacker and victim.
  """
  def commit(conn, event) do
    conn =
      conn
      |> assign(:attacker, event.data.attacker)
      |> assign(:victim, event.data.victim)

    conn = Enum.reduce(event.data.effects, conn, &render_effect(&2, &1, event))

    conn
    |> update_character(event)
    |> assign(:character, conn.character)
    |> prompt(CommandView, "prompt")
  end

  @doc """
  An abort is recieved if victim and/or room rejects turn request for whatever reason.
  """
  def abort(conn, event) do
    conn
    |> assign(:reason, event.reason)
    |> assign(:victim, event.victim)
    |> render(ArenaView, "turn/error")
    |> put_combat_flash(:turn_requested?, false)
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

  defp render_effect(conn, effect = %Damage{}, context) do
    conn
    |> assign(:type, effect.type)
    |> assign(:verb, effect.verb)
    |> assign(:damage, effect.amount)
    |> render(ArenaView, damage_topic(conn, context))
  end

  defp damage_topic(conn, event) do
    id = conn.character.id

    cond do
      id == event.data.attacker.id -> "damage/attacker"
      id == event.data.victim.id -> "damage/victim"
      true -> "damage/witness"
    end
  end

  defp update_character(conn, event) do
    id = conn.character.id

    cond do
      id == event.data.attacker.id -> update_attacker(conn, event)
      id == event.data.victim.id -> update_victim(conn, event)
      true -> conn
    end
  end

  defp update_attacker(conn, event) do
    conn
    |> put_combat_flash(:on_turn?, false)
    |> put_combat_flash(:turn_requested?, false)
  end

  defp update_victim(conn, event) do
    conn
    |> update_threat(event)
  end

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
