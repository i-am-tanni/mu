defmodule Mu.Character.ListAction do
  use Mu.Character.Action
  import Mu.Character.Guards

  @impl true
  def run(conn, %{type: :characters}) when is_non_player(conn) do
    event(conn, "room/chars")
  end

  @impl true
  def build(params, _opts \\ []) do
    %Action{
      type: __MODULE__,
      priority: 6,
      conditions: [:pos_standing],
      steps: [
        Action.step(__MODULE__, 0, params)
      ]
    }
  end
end
