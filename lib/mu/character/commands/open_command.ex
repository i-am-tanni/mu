defmodule Mu.Character.OpenCommand do
  use Kalevala.Character.Command

  def run(conn, params) do
    conn
    |> event("room/open", %{text: params["text"]})
    |> assign(:prompt, false)
  end
end
