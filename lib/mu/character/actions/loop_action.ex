defmodule Mu.Character.StopAction do
  use Kalevala.Character.Action
  alias Mu.Character.Action

  @impl true
  def run(conn, _params), do: Action.stop(conn)
end

defmodule Mu.Character.LoopAction do
  @moduledoc """
  Loops an action either a specified number of times or infinitely
  """

  use Kalevala.Character.Action
  alias Mu.Character.Action.Step
  alias Mu.Character.Action

  @impl true
  def run(conn, %{action: action, count: count}) do
    case count > 1 do
      true -> Action.loop(conn, action, count: count - 1)
      false -> conn
    end
  end

  @impl true
  def run(conn, action), do: Action.loop(conn, action)

  def build(action, opts \\ []) do
    params =
      case Keyword.get(opts, :count) do
        nil -> action
        count -> %{action: action, count: count}
      end

    loop_step = %Step{
      callback_module: __MODULE__,
      delay: 0,
      params: params
    }

    %{action | steps: action.steps ++ [loop_step]}
  end
end
