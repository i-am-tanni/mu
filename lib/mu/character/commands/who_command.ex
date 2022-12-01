defmodule Mu.Character.WhoCommand do
  use Kalevala.Character.Command

  alias Mu.Character.WhoView
  alias Mu.Character.Presence

  def run(conn, _params) do
    conn
    |> assign(:characters, Presence.characters())
    |> render(WhoView, "list")
  end
end
