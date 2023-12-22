defmodule Mu.Character.CombatCommand do
  use Kalevala.Character.Command

  alias Mu.Character
  alias Mu.Character.CombatAction

  def request(conn, params) do
    text = params["text"]
    data = Character.build_attack(conn, text)

    conn
    |> CombatAction.run(data)
    |> assign(:prompt, false)
  end
end
