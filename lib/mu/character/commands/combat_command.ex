defmodule Mu.Character.CombatCommand do
  use Kalevala.Character.Command

  alias Mu.Character.KillAction

  def request(conn, params) do
    text = params["text"]

    conn
    |> KillAction.run(%{text: text})
    |> assign(:prompt, false)
  end
end
