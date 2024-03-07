defmodule Mu.Character.EventAction do
  @moduledoc """
  A generic action that sends an event
  """

  use Mu.Character.Action

  @impl true
  def run(conn, %{topic: topic, data: data}) do
    event(conn, topic, data)
  end

  @impl true
  def build(params, _opts \\ []) do
    %Action{
      type: __MODULE__,
      priority: 5,
      conditions: [],
      steps: [
        Action.step(__MODULE__, 0, params)
      ]
    }
  end

  def publish_error(conn, _error), do: conn
end
