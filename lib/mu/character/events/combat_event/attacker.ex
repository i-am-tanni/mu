defmodule Mu.Character.CombatEvent.Attacker do
  use Kalevala.Character.Event
  import Kalevala.Character.Conn

  alias Mu.Character.CombatView
  alias Mu.Character.CommandView

  def kickoff(conn, event) do
    target = get_meta(conn, :target)

    target =
      case is_nil(target) do
        true -> event.data.victim
        false -> target
      end

    conn
    |> put_meta(:target, target)
    |> put_meta(:mode, :combat)
  end

  def update(conn, _event), do: conn

  def abort(conn, event) do
    conn
    |> assign(:reason, event.data.reason)
    |> render(CombatView, "error")
    |> assign(:character, conn.character)
    |> prompt(CommandView, "prompt")
  end
end
