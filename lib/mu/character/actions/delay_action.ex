defmodule Mu.Character.DelayAction do
  use Kalevala.Character.Action

  alias Mu.Character.Action
  alias Mu.Character.Action.Step

  @impl true
  def run(conn, _params), do: conn

  def build(action, delay) do
    pre_delay = %Step{
      delay: delay,
      callback_module: __MODULE__,
      params: %{}
    }

    %Action{action | steps: [pre_delay | action.steps]}
  end
end
