defmodule Mu.Character.Action.Step do
  @moduledoc """
  An atomic part of an action
  """
  defstruct [:callback_module, :params, :delay]
end

defmodule Mu.Character.Action do
  @type t() :: %__MODULE__{}
  @callback run(Conn.t(), map()) :: Conn.t()
  @callback build(map(), list()) :: t()

  defstruct [:id, :type, :priority, :conditions, :steps]

  defmacro __using__(_opts) do
    quote do
      import Kalevala.Character.Conn
      alias Mu.Character.Action
      @behaviour Mu.Character.Action

      @doc """
      Build the action and put it in the action queue
      """
      def put(conn, params, opts \\ []) do
        action = build(params, opts)
        Mu.Character.Action.put(conn, action, opts)
      end

      defoverridable put: 3
    end
  end

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

  alias Mu.Character.Action.Validate

  alias Mu.Character.CommandView
  alias Mu.Character.LoopAction
  alias Mu.Character.DelayAction

  @doc """
  Adds a loop step to the action's step list.
  If opts receives count: n, then will loop n times. Otherwise, indefinitely (until cancelled).
  """
  def loop(conn, action, opts \\ []) do
    action = LoopAction.build(action, opts)
    put(conn, action, opts)
  end

  @doc """
  Halts all current and pending actions.
  """
  def stop(conn) do
    conn
    |> put_meta(:action_queue, [])
    |> put_meta(:processing_action, nil)
  end

  @doc """
  Queues the next action if the priority is equal or lower and character is busy.
  Else it overrides all outstanding actions and cancels the remainder.
  """
  def put(conn, action, opts \\ []) do
    action =
      if pre_delay = Keyword.get(opts, :pre_delay),
        do: DelayAction.build(action, delay: pre_delay),
        else: action

    action =
      if priority_override = Keyword.get(opts, :priority),
        do: %{action | priority: priority_override},
        else: action

    action = %{action | id: Kalevala.Character.generate_id()}
    character = character(conn)
    processing_action = character.meta.processing_action
    action_queue = character.meta.action_queue
    priority = action.priority

    case is_nil(processing_action) or priority < processing_action.priority do
      true ->
        conn
        |> progress(action)
        |> put_meta(:action_queue, [])

      false ->
        conn
        |> put_meta(:action_queue, action_queue ++ [action])
    end
  end

  @doc """
  Progresses an action or the next action in the queue
  In the case of an error, abort the current action and any remaining queued actions
  """
  def progress(conn, action) do
    case check_conditions(conn, action) do
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

  @doc """
  A wrapper around an action that runs when called. An action is made up of 1 - n steps.
  """
  def step(callback_module, delay, params) do
    %Mu.Character.Action.Step{
      callback_module: callback_module,
      delay: delay,
      params: params
    }
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
        schedule_next_progress(delay, action.id)
        conn

      0 ->
        perform(conn, action)
    end
  end

  # ...unless there's no steps left
  defp perform(conn, %{steps: []}) do
    character = character(conn)

    # In which case, pop the next action in the queue
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

  defp schedule_next_progress(delay, id) do
    event = %Kalevala.Event{
      topic: :action_next,
      data: %{id: id},
      from_pid: self()
    }

    Process.send_after(self(), event, delay)
  end

  defp check_conditions(conn, action) do
    Enum.reduce(action.conditions, :ok, fn fun_name, acc ->
      case acc do
        :ok -> apply(Validate, fun_name, [conn])
        {:error, reason} -> {:error, reason}
      end
    end)
  end
end

defmodule Mu.Character.Action.ValidateMacros do
  defmacro poses(poses) do
    for pose <- poses do
      quote do
        def unquote(pose)(conn), do: min_pose(conn, unquote(pose))
      end
    end
  end
end

defmodule Mu.Character.Action.Validate do
  @moduledoc """
  Validations to check if action can be performed.
  All functions accept character as an argument and return `:ok` or `{:error, reason}`
  """

  import Mu.Character.Action.ValidateMacros
  import Mu.Character.Guards

  poses([:pos_dying, :pos_sleeping, :pos_sitting, :pos_standing, :pos_fleeing, :pos_fighting])

  def not_fighting(conn) when in_combat(conn), do: {:error, "You are fighting for your life!"}
  def not_fighting(_), do: :ok

  defp min_pose(conn, min_required_pose) do
    current_pose = conn.character.meta.pose

    case pose_to_val(current_pose) >= pose_to_val(min_required_pose) do
      true -> :ok
      false -> {:error, error_msg_pos(current_pose)}
    end
  end

  defp error_msg_pos(pose) do
    case pose do
      :pos_dying -> "You will die if not aided soon."
      :pos_sleeping -> "What -- in your dreams?"
      :pos_fleeing -> "You panic as you try escape with your life!"
      :pos_fighting -> "You are fighting for your life!"
    end
  end

  defp pose_to_val(pose) do
    case pose do
      :pos_dying -> 0
      :pos_sleeping -> 1
      :pos_sitting -> 2
      :pos_fleeing -> 3
      :pos_standing -> 4
      :pos_fighting -> 5
    end
  end
end
