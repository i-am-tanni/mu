defmodule Mu.Character.QuitCommand do
  use Kalevala.Character.Command

  alias Mu.Character.QuitView

  def run(conn, _params) do
    conn
    |> assign(:prompt, false)
    |> render(QuitView, "goodbye")
    |> halt()
  end
end
