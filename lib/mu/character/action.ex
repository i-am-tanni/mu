defmodule Mu.Character.Action.Step do
  @moduledoc """
  An atomic part of an action
  """
  defstruct [:callback_module, :params, :delay]
end

defmodule Mu.Character.Action do
  defstruct [:priority, :conditions, :steps]

  @moduledoc """
  Actions are a wrapper around discrete character functionality that:
  - (optionally) takes time to complete
  - consists of one or more steps
  - blocks other actions from occuring while an action is completing
  - can be cancelled by higher priority actions
  - automatically checks if all conditions are met to perform the next action or step
  - can be chained in a queue for actions with priority <= the processing_action priority

  ##Action cancelling

  Priority is in reverse order where higher priority is defined as the lesser of two numbers:
  - 0:  is the highest priority (non-cancellable action)
  - 1: can only be cancelled by priority 0 actions)
  ..
  - n: can only be cancelled by priority < n actions

  Any error resulting from the current action cancels all remaining in the queue.
  """

  import Kalevala.Character.Conn
  alias Mu.Character.CommandView

  @doc """
  Queues the next action if the priority is equal or lower and character is busy.
  Else it overrides all outstanding actions and cancels the remainder.
  """
  def put(conn, action) do
    character = character(conn)
    processing_action = character.meta.processing_action
    action_queue = character.meta.action_queue
    %{priority: priority} = action

    case is_nil(processing_action) or priority < processing_action.priority do
      true ->
        conn
        |> progress(action)
        |> put_meta(:action_queue, [])

      false ->
        conn
        |> put_meta(:action_queue, action_queue ++ action)
    end
  end

  @doc """
  Progresses an action or the next action in the queue
  In the case of an error, abort the current action and any remaining queued actions
  """
  def progress(conn, action) do
    character = character(conn)

    case check_conditions(character, action) do
      :ok ->
        perform(conn, action)

      {:error, reason} ->
        conn
        |> assign(:reason, reason)
        |> prompt(CommandView, "error")
        |> put_meta(:action_queue, [])
        |> put_meta(:processing_action, nil)
    end
  end

  # private functions

  defp perform(conn, action = %{steps: [head | rest]}) do
    action = %{action | steps: rest}

    conn =
      conn
      |> run(head)
      |> put_meta(:processing_action, action)

    case head.delay do
      delay when delay > 0 ->
        schedule_next_progress(delay)
        conn

      0 ->
        perform(conn, action)
    end
  end

  defp perform(conn, %{steps: []}) do
    character = character(conn)

    case character.meta.action_queue do
      [next | rest] ->
        conn
        |> progress(next)
        |> put_meta(:action_queue, rest)

      [] ->
        put_meta(conn, :processing_action, nil)
    end
  end

  defp run(conn, %{callback_module: callback_module, params: params}) do
    apply(callback_module, :run, [conn, params])
  end

  defp schedule_next_progress(delay) do
    event = %Kalevala.Event{
      topic: "action/next",
      data: %{},
      from_pid: self()
    }

    Process.send_after(self(), event, delay)
  end

  defp check_conditions(character, action) do
    Enum.reduce(action.conditions, :ok, fn fun, acc ->
      case acc do
        :ok -> fun.(character)
        {:error, reason} -> {:error, reason}
      end
    end)
  end
end

defmodule Mu.Character.Action.Validate do
  @moduledoc """
  Validations to check if action can be performed.
  All functions accept character as an argument and return `:ok` or `{:error, reason}`
  """
  def alive(character) do
    case character.meta.vitals.health_points > 0 do
      true -> :ok
      false -> {:error, "You are unconscious."}
    end
  end
end
