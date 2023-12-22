defmodule Mu.Character.CombatCommand do
  use Kalevala.Character.Command

  alias Mu.Character.CombatAction

  def request(conn, params) do
    text = params["text"]

    conn
    |> CombatAction.run(%{text: text})
    |> assign(:prompt, false)
  end
end
