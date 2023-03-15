defmodule Mu.Character.RandomExitCommand do
  use Kalevala.Character.Command
  alias Mu.Character.WanderAction

  def wander(conn, params) do
    WanderAction.run(conn, params)
  end
end
