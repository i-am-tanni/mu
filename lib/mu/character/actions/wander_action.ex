defmodule Mu.Character.WanderAction do
  @moduledoc """
  Command to choose a random exit
  """
  use Mu.Character.Action

  @impl true
  def run(conn, params) do
    conn
    |> event("room/wander", params)
    |> assign(:prompt, false)
  end

  @impl true
  def build(params, opts \\ []) do
    delay = Keyword.get(opts, :delay, 500)

    %Action{
      type: __MODULE__,
      priority: 8,
      conditions: [:pos_fleeing],
      steps: [
        Action.step(__MODULE__, delay, params)
      ]
    }
  end

  def loop(conn, params, opts \\ []) do
    action = build(params, opts)
    Action.loop(conn, action, opts)
  end
end
