defmodule Mu.Character.BuildEvent do
  use Kalevala.Character.Event

  alias Mu.Character.BuildView

  def call(conn, %{data: %{exit_name: exit_name}}) do
    conn
    |> assign(:exit_name, exit_name)
    |> render(BuildView, "dig")
    |> request_movement(exit_name)
    |> assign(:prompt, false)
  end
end
