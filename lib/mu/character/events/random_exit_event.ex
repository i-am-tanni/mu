defmodule Mu.Character.RandomExitEvent do
  use Kalevala.Character.Event
  alias Mu.Character.MoveView

  def call(conn, %{data: %{exits: []}}) do
    conn
    |> assign(:reason, "no-exits")
    |> render(MoveView, "fail")
  end

  def call(conn, %{data: %{exits: exits}}) do
    exit_name = Enum.random(exits)
    request_movement(conn, exit_name)
  end
end
