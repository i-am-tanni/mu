defmodule Mu.Character.ArenaEvent do
  @moduledoc """
  Events for in-progress combat events that occur in the instanced arena.
  For initiating combat, see CombatEvent.
  """

  use Kalevala.Character.Event

  alias Mu.World.Arena.Damage
  alias Mu.Character.ArenaView
  alias Mu.Character.CommandView
  alias Mu.Character.ArenaEvent.Victim
  alias Mu.Character.ArenaEvent.Attacker

  # Public interface

  @doc """
  A turn notificiation is received from the arena when it is your turn.
  """
  def notify(conn, event), do: Attacker.notify_on_turn(conn, event)
  def npc_notify(conn, event), do: Attacker.npc_notify_on_turn(conn, event)

  @doc """
  A turn request is received by the victim from the attacker for the victim's approval or rejection.
  If approved, victim processes turn outcome.
  """
  def request(conn, event), do: Victim.request(conn, event)

  @doc """
  A turn request has been aported / rejected by room or victim for whatever reason
  """
  def abort(conn, event), do: Attacker.abort(conn, event)

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

  # Private Functions

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
      id == event.data.attacker.id -> Attacker.update(conn, event)
      id == event.data.victim.id -> Victim.update(conn, event)
      true -> conn
    end
  end
end
