defmodule Mu.Character.CombatRequest do
  defstruct [
    :attacker,
    :victims,
    :target_count,
    :verb,
    :hitroll,
    :speed,
    round_based?: false,
    damages: [],
    effects: []
  ]
end

defmodule Mu.Character.CombatCommit do
  defstruct [:round_based?, :attacker, :victim, :verb, :damage, effects: []]
end

defmodule Mu.Character.DamageSource do
  defstruct [:damroll, :type]
end

defmodule Mu.Character.Threat do
  defstruct [:id, :character, :value, :expires_at]
end

defmodule Mu.Character.CombatEvent do
  @moduledoc """
  When a combat packet is received by the victim, it is either:
  - Rejected and the attacker is informed to abort the combat action with the reason.
  - Approved and the combat packet is committed immediately by the victim to prevent race conditions

  If approved, the victim commits immediately to prevent race conditions.
  After which, the attacker and any witnesses are notified.

  A notification entails updating threat tables and target health

  #Threat Table

  Tracks threat per character and is used to help determine which target to attack.

  The threat table persists between rooms, but threat data has an expiration date.

  Is used to choose who to attack or who to hunt.

  """
  use Kalevala.Character.Event
  import Mu.Utility
  import Mu.Character.Guards

  alias Mu.Character
  alias Mu.Character.CombatEvent.Attacker
  alias Mu.Character.CombatEvent.Victim
  alias Mu.Character.CombatView
  alias Mu.Character.CommandView
  alias Mu.Character.AutoAttackAction

  def request(conn, event), do: Victim.request(conn, event)

  def abort(conn, event), do: Attacker.abort(conn, event)

  def kickoff(conn, event) do
    attacker = event.data.attacker
    victim = event.data.victim

    self_id = conn.character.id
    victim_id = victim.id

    conn =
      case !in_combat(conn) and self_id in [victim_id, attacker.id] do
        true ->
          target = if self_id == victim_id, do: attacker, else: victim

          character = character(conn)
          meta = %{character.meta | in_combat?: true, target: target, pose: :pos_fighting}
          flash = %{foes: MapSet.new([target.id])}

          conn
          |> put_character(%{character | meta: meta})
          |> put_controller(combat_controller(conn), flash)

        false ->
          conn
      end

    conn
    |> assign(:attacker, attacker)
    |> assign(:victim, victim)
    |> prompt(CombatView, kickoff_topic(conn, event))
    |> prompt(CommandView, "prompt")
    |> commit(event)
  end

  defp combat_controller(conn) when is_non_player(conn), do: Mu.Character.AiCombatController
  defp combat_controller(conn) when is_player(conn), do: Mu.Character.CombatController

  def commit(conn, event) do
    attacker = event.data.attacker
    advance_round? = event.data.round_based? and conn.character.id == attacker.id

    conn
    |> assign(:attacker, attacker)
    |> assign(:victim, event.data.victim)
    |> render_effects(event)
    |> update_character(event)
    |> then_if(advance_round?, fn conn ->
      # tell room to advance next round segement
      event(conn, "round/pop", %{})
    end)
  end

  def end_round(conn, _event) when in_combat(conn) do
    target = get_meta(conn, :target)

    conn
    |> assign(:character, conn.character)
    |> assign(:target, target)
    |> prompt(CombatView, "prompt")
    |> prompt(CommandView, "prompt")
    |> then_if(&Character.in_combat?/1, fn conn ->
      AutoAttackAction.run(conn, %{target: target.id})
    end)
  end

  def end_round(conn, _), do: conn

  def death_notice(conn, event) do
    conn
    |> assign(:victim, event.data.victim)
    |> assign(:attacker, event.data.attacker)
    |> assign(:death_cry, event.data.death_cry)
    |> render(CombatView, death_topic(conn, event))
  end

  # updates

  defp update_character(conn, event) when in_combat(conn) do
    case conn.character.id == event.data.victim.id do
      true -> Victim.update(conn, event)
      false -> Attacker.update(conn, event)
    end
  end

  defp update_character(conn, _), do: conn

  # renders

  defp render_effects(conn, event) do
    data = event.data
    damage = data.damage

    case damage > 0 do
      true ->
        conn
        |> assign(:verb, data.verb)
        |> assign(:damage, damage)
        |> render(CombatView, damage_topic(conn, event))

      false ->
        # suppress damage attempts that yield no result
        conn
    end
  end

  # topics

  defp kickoff_topic(conn, event) do
    id = conn.character.id

    cond do
      id == event.data.attacker.id -> "kickoff/attacker"
      id == event.data.victim.id -> "kickoff/victim"
      true -> "kickoff/witness"
    end
  end

  defp damage_topic(conn, event) do
    id = conn.character.id

    cond do
      id == event.data.attacker.id -> "damage/attacker"
      id == event.data.victim.id -> "damage/victim"
      true -> "damage/witness"
    end
  end

  defp death_topic(conn, event) do
    id = conn.character.id

    cond do
      id == event.data.attacker.id -> "death/attacker"
      id == event.data.victim.id -> "death/victim"
      true -> "death/witness"
    end
  end
end
