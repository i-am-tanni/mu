defmodule Mu.Character.RandomExitCommand do
  use Kalevala.Character.Command
  alias Mu.Character.WanderAction
  alias Mu.Character.FleeAction
  alias Mu.Character.Action

  def wander(conn, params) do
    WanderAction.run(conn, params)
  end

  def flee(conn, params) do
    case Mu.Character.in_combat?(conn) do
      true ->
        action = FleeAction.build(%{})
        Action.put(conn, action)

      false ->
        WanderAction.run(conn, params)
    end
  end
end
