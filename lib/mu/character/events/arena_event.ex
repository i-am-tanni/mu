defmodule Mu.Character.ArenaEvent do
  @moduledoc """
  Events for in-progress combat events.
  For initiating combat events, see CombatEvent.
  """

  use Kalevala.Character.Event
  import Mu.Character.CombatFlash

  alias Mu.World.Arena.Damage
  alias Mu.Character.ArenaView
  alias Mu.Character.CommandView

  def npc_autoattack(conn, _event) do
    data = %{
      type: :attack,
      attacker: conn.character,
      victim: :random,
      turn_cost: 1000,
      effects: [
        struct!(Damage, verb: "punch", type: :blunt, amount: 2)
      ]
    }

    Mu.Character.TurnAction.run(conn, data)
  end

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

  def request(conn, event) do
    event(conn, "turn/commit", event.data)
  end

  def commit(conn, event) do
    conn =
      conn
      |> assign(:attacker, event.data.attacker)
      |> assign(:victim, event.data.victim)

    conn =
      Enum.reduce(event.data.effects, conn, fn effect, acc ->
        render_effect(acc, effect, event)
      end)

    conn
    |> update_character(event)
    |> assign(:character, conn.character)
    |> prompt(CommandView, "prompt")
  end

  def abort(conn, event) do
    conn
    |> assign(:reason, event.reason)
    |> assign(:victim, event.victim)
    |> render(ArenaView, "turn/error")
    |> put_combat_flash(:turn_requested?, false)
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
    |> event("turn/complete", %{})
  end

  defp update_threat(conn, event) do
    threat_table = get_combat_flash(conn, :threat_table)
    max_hp = conn.character.meta.vitals.max_health_points

    total_damage =
      Enum.reduce(event.data.effects, 0, fn
        %Damage{amount: amount}, acc -> acc + amount
        _, acc -> acc
      end)

    id = event.data.attacker.id
    threat = total_damage / max_hp * 1000
    threat = threat + Map.get(threat_table, id, 0)
    threat_table = Map.put(threat_table, id, threat)
    put_combat_flash(conn, :threat_table, threat_table)
  end
end
