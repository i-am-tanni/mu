defmodule Mu.Character.KillAction do
  @moduledoc """
  Request to initiate combat
  """

  use Kalevala.Character.Action

  alias Mu.Character

  @impl true
  def run(conn, params) do
    params = Character.build_auto_attack(params.text)

    Enum.reduce(1..1, conn, fn _, acc ->
      event(acc, "combat/request", params)
    end)
  end
end
