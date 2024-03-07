defmodule Mu.Character.CombatCommand do
  use Kalevala.Character.Command

  alias Mu.Character
  alias Mu.Character.CombatAction

  def request(conn, params) do
    text = params["text"]
    attack_data = Character.build_attack(conn, text)
    attack_data = %{attack_data | round_based?: false}

    conn
    |> CombatAction.run(attack_data)
    |> assign(:prompt, false)
  end
end
