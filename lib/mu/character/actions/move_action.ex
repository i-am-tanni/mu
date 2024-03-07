defmodule Mu.Character.MoveAction do
  use Mu.Character.Action

  @impl true
  def run(conn, %{direction: direction}) do
    request_movement(conn, direction)
  end

  @impl true
  def build(params, _opts \\ []) do
    %{direction: direction} = params

    %Action{
      type: __MODULE__,
      priority: 1,
      conditions: [:pos_standing, :not_fighting],
      steps: [
        Action.step(__MODULE__, 500, %{direction: direction})
      ]
    }
  end
end
