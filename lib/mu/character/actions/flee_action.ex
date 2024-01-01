defmodule Mu.Character.FleeAction do
  @moduledoc """
  Attempt to abort combat by choosing a random exit
  """

  use Kalevala.Character.Action
  alias Mu.Character.Action
  alias Mu.Character.Action.Step
  alias Mu.Character.Action.Validate

  @impl true
  def run(conn, _params) do
    Mu.Character.WanderAction.run(conn, %{})
  end

  def build(params \\ %{}) do
    %Action{
      priority: 1,
      conditions: [&Validate.alive/1],
      steps: [
        %Step{
          callback_module: __MODULE__,
          delay: 0,
          params: %{}
        }
      ]
    }
  end
end
