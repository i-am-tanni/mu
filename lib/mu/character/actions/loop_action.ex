defmodule Mu.Character.LoopAction do
  @moduledoc """
  Modifies the last step in an action so that it will loop.
  Can loop a finite number of times or indefinitely (until cancelled).
  """

  use Mu.Character.Action

  @impl true
  def run(conn, %{action: action, count: :infinity}) do
    Action.loop(conn, action)
  end

  @impl true
  def run(conn, %{action: action, count: loops_remaining}) do
    case loops_remaining > 1 do
      true -> Action.loop(conn, action, count: loops_remaining - 1)
      false -> conn
    end
  end

  @impl true
  def build(action, opts \\ []) do
    loop_count = Keyword.get(opts, :count, :infinity)
    params = %{action: action, count: loop_count}
    loop_step = Action.step(__MODULE__, 0, params)
    %{action | steps: action.steps ++ [loop_step]}
  end
end
