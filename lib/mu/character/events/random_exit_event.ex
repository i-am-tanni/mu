defmodule Mu.Character.RandomExitEvent do
  use Kalevala.Character.Event

  def call(conn, %{data: %{exits: exits}}) do
    exit_name = Enum.random(exits)
    request_movement(conn, exit_name)
  end
end
