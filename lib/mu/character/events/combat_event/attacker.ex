defmodule Mu.Character.CombatEvent.Attacker do
  use Kalevala.Character.Event
  import Kalevala.Character.Conn

  alias Mu.Character.CombatView
  alias Mu.Character.CommandView

  # Health of the target and any potential targets is tracked on all witnesses
  # Health is reported at "round/end" for the current target, thus it's necessary to update the target's health
  # But also necessary to also track the health of any *potential* targets as well (i.e. threats)
  # This is because if a target ever changes, it may not be readily apparent what their health points are.
  # E.g. if the last blow of a round causes the target to die and the attacker switches targets
  # And it's tricky to ask the victim to report their health on the fly asynchronously
  # Definitely an area that may warrant a refactor at a later date

  def update(conn, event) do
    victim = event.data.victim
    victim_id = victim.id

    # update threat data
    threat_table = get_meta(conn, :threat_table)

    threat_table =
      case Map.get(threat_table, victim_id) do
        threat = %Mu.Character.Threat{} ->
          threat = %{threat | character: victim}
          Map.put(threat_table, victim_id, threat)

        nil ->
          threat_table
      end

    # update target data
    target = get_meta(conn, :target)

    target =
      case target.id == victim_id do
        true -> victim
        false -> target
      end

    conn
    |> put_meta(:threat_table, threat_table)
    |> put_meta(:target, target)
  end

  def abort(conn, event) do
    conn
    |> assign(:reason, event.data.reason)
    |> render(CombatView, "error")
    |> prompt(CommandView, "prompt")
  end
end
