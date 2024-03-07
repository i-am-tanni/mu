defmodule Mu.Character.RandomExitCommand do
  use Kalevala.Character.Command
  import Mu.Character.Guards

  alias Mu.Character.WanderAction
  alias Mu.Character.CombatView

  def call(conn, _params) when in_combat(conn) do
    case get_meta(conn, :pose) != :pos_fleeing do
      true ->
        conn
        |> WanderAction.put(%{}, pre_delay: 4000)
        |> render(CombatView, "flee/attempt")
        |> put_meta(:pose, :pos_fleeing)
        |> assign(:prompt, false)

      false ->
        conn
    end
  end

  def call(conn, _params) do
    conn
    |> WanderAction.put(%{})
    |> assign(:prompt, false)
  end
end
