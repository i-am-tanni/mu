defmodule Mu.Character.RandomExitCommand do
  use Kalevala.Character.Command

  def wander(conn, params) do
    conn
    |> event("room/wander", params)
    |> assign(:prompt, false)
  end
end
