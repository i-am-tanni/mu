defmodule Mu.Character.ArenaEvent.Attacker do
  @moduledoc """
  Combat events related to the on-turn character
  """

  use Kalevala.Character.Event
  import Mu.Character.CombatFlash
  alias Mu.World.Arena.Damage

  @doc """
  Notify a player they are on turn.
  If there are turns in the turn queue, pull from the queue first for next turn action.
  Otherwise, mark character as on-turn.
  """
  def notify_on_turn(conn, event) do
    turn_queue = get_combat_flash(conn, :turn_queue)

    case turn_queue do
      [[] | turn_queue] ->
        conn
        |> put_combat_flash(:turn_queue, turn_queue)
        |> notify_on_turn(event)

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

  def npc_notify_on_turn(conn, event) do
    npc_autoattack(conn, event)
  end

  @doc """
  Abort current turn action and inform attacker.
  This does NOT mean attacker forfeits turn.
  They are simply inform their turn request was denied for whatever reason and to try again.
  """
  def abort(conn, event) do
    IO.inspect(event.data.reason, label: "<reason>")

    conn
    |> assign(:reason, event.data.reason)
    |> assign(:victim, event.data.victim)
    |> render(ArenaView, event.data.reason)
    |> put_combat_flash(:turn_requested?, false)
    |> notify_on_turn(event)
  end

  def update(conn, _event) do
    conn
    |> put_combat_flash(:on_turn?, false)
    |> put_combat_flash(:turn_requested?, false)
  end

  defp npc_autoattack(conn, _event) do
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
end
