defmodule Mu.Character.KillAction do
  @moduledoc """
  Request to initiate combat
  """

  use Kalevala.Character.Action

  @impl true
  def run(conn, params) do
    event(conn, "combat/request", params)
  end
end

defmodule Mu.Character.TurnAction do
  @moduledoc """
  Request to take turn
  """

  use Kalevala.Character.Action
  import Mu.Character.CombatFlash

  @impl true
  def run(conn, params) do
    case get_combat_flash(conn, :turn_requested?) == false do
      true ->
        conn
        |> put_combat_flash(:turn_requested?, true)
        |> event("turn/request", params)

      false ->
        turn_queue = get_combat_flash(conn, :turn_queue)
        put_combat_flash(conn, :turn_queue, turn_queue ++ [params])
    end
  end
end
