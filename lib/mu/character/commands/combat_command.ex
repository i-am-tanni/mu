defmodule Mu.Character.CombatCommand do
  use Kalevala.Character.Command
  import Mu.Character.CombatFlash

  alias Mu.Character.KillAction
  alias Mu.Character.TurnAction
  alias Mu.Character.FleeAction

  alias Mu.World.Arena.Damage

  def request(conn, params) do
    text = params["text"]

    conn
    |> KillAction.run(%{text: text})
    |> assign(:prompt, false)
  end

  def attack(conn, params) do
    case _in_combat? = get_meta(conn, :mode) == :combat do
      true ->
        turn = build_attack(conn, params)
        turn_queue = get_combat_flash(conn, :turn_queue)

        case get_combat_flash(conn, :on_turn?) and turn_queue == [] do
          true -> TurnAction.run(conn, turn)
          false -> put_combat_flash(conn, :turn_queue, turn_queue ++ [turn])
        end

      false ->
        render(conn, CombatView, "not-in-combat")
    end
  end

  def flee(conn, _params) do
    params = %{attribute: 100}

    conn
    |> FleeAction.run(params)
    |> assign(:prompt, false)
  end

  def build_attack(conn, params) do
    %{
      type: :attack,
      attacker: conn.character,
      victim: Map.get(params, "target", :random),
      turn_cost: 1000,
      effects: [
        struct!(Damage, verb: "punch", type: :blunt, amount: 6)
      ]
    }
  end
end
