defmodule Mu.Character.LookAction do
  use Mu.Character.Action
  import Mu.Character.Guards

  @impl true
  def run(conn, params) when is_player(conn) do
    event(conn, "room/look-arg", params)
  end

  def run(conn, %{at: :characters}) when is_non_player(conn) do
    event(conn, "room/chars")
  end

  @impl true
  def build(params, _opts \\ []) do
    %Action{
      type: __MODULE__,
      priority: 6,
      conditions: [:pos_sitting],
      steps: [
        Action.step(__MODULE__, 0, params)
      ]
    }
  end
end
