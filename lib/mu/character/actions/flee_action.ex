defmodule Mu.Character.FleeAction do
  @moduledoc """
  Initiate combat
  """

  use Kalevala.Character.Action

  @impl true
  def run(conn, _params) do
    request_movement(conn, "flee")
  end
end
