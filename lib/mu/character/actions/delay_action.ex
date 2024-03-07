defmodule Mu.Character.DelayAction do
  @moduledoc """
  A wrapper around an action to give it a pre-delay.
  Adds a dummy step with a delay to the front of the action's steps list.
  """
  use Mu.Character.Action

  @impl true
  def run(conn, _params), do: conn

  @impl true
  def build(action, delay: delay) do
    pre_delay = Action.step(__MODULE__, delay, %{})
    %Action{action | steps: [pre_delay | action.steps]}
  end
end
