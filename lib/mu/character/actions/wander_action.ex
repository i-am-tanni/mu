defmodule Mu.Character.WanderAction do
  @moduledoc """
  Command to choose a random exit
  """
  use Kalevala.Character.Action

  def run(conn, params) do
    conn
    |> event("room/wander", params)
    |> assign(:prompt, false)
  end
end
