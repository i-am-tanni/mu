defmodule Mu.Character.SpeedWalkAction do
  @moduledoc """
  Attempts to walk a list of exit names
  """
  use Mu.Character.Action

  alias Mu.Character.MoveAction

  @impl true
  def run(conn, params), do: MoveAction.run(conn, params)

  @impl true
  def build(%{directions: directions}, opts \\ []) do
    delay = Keyword.get(opts, :delay, 500)
    delay = max(delay, 250)

    steps =
      Enum.map(directions, fn direction ->
        Action.step(__MODULE__, delay, %{direction: direction})
      end)

    %Action{
      type: __MODULE__,
      priority: 8,
      conditions: [:pos_standing],
      steps: steps
    }
  end
end
