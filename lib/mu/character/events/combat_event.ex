defmodule Mu.Character.CombatRequest do
  defstruct [:attacker, :victims, :verb, :hitroll, :speed, damages: [], effects: []]
end

defmodule Mu.Character.CombatCommit do
  defstruct [:attacker, :victim, :verb, :damage, effects: []]
end

defmodule Mu.Character.DamageSource do
  defstruct [:damroll, :type]
end

defmodule Mu.Character.Threat do
  defstruct [:id, :character, :value, :expires_at]
end

defmodule Mu.Character.CombatEvent do
  use Kalevala.Character.Event
  import Mu.Utility

  alias Mu.Character
  alias Mu.Character.CombatEvent.Attacker
  alias Mu.Character.CombatEvent.Victim
  alias Mu.Character.CombatView
  alias Mu.Character.CommandView
  alias Mu.Character.AutoAttackAction

  @round_length_ms 3000

  def request(conn, event), do: Victim.request(conn, event)

  def abort(conn, event), do: Attacker.abort(conn, event)

  def kickoff(conn, event) do
    attacker = event.data.attacker
    victim = event.data.victim

    conn
    |> assign(:attacker, attacker)
    |> assign(:victim, victim)
    |> prompt(CombatView, kickoff_topic(conn, event))
    |> update_kickoff(event)
    |> commit(event)
    |> then_if(conn.character.id in [attacker.id, victim.id], fn conn ->
      character = character(conn)
      AutoAttackAction.run(conn, %{target: character.meta.target.id})
    end)
  end

  @doc """
  Commit a combat packet from a round -- one segement of a round
  """
  def commit_round(conn, event) do
    conn
    |> commit(event)
    |> then_if(conn.character.id == event.data.attacker.id, fn conn ->
      event(conn, "round/pop", %{})
    end)
  end

  def commit(conn, event) do
    conn
    |> assign(:attacker, event.data.attacker)
    |> assign(:victim, event.data.victim)
    |> render_effects(event)
    |> update_character(event)
  end

  def end_round(conn, _event) do
    target = conn.character.meta.target

    case is_nil(target) do
      true ->
        conn
        |> assign(:character, conn.character)
        |> prompt(CommandView, "prompt")

      false ->
        conn
        |> assign(:character, conn.character)
        |> assign(:target, target)
        |> prompt(CombatView, "prompt")
        |> prompt(CommandView, "prompt")
        |> then_if(conn.character.meta.mode == :combat, fn conn ->
          AutoAttackAction.run(conn, %{target: target.id})
        end)
    end
  end

  # updates

  defp update_kickoff(conn, event) do
    id = conn.character.id

    cond do
      id == event.data.attacker.id -> Attacker.kickoff(conn, event)
      id == event.data.victim.id -> Victim.kickoff(conn, event)
      true -> conn
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

  # renders

  defp render_effects(conn, event) do
    data = event.data

    conn
    |> assign(:verb, data.verb)
    |> assign(:damage, data.damage)
    |> render(CombatView, damage_topic(conn, event))
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
end
