defmodule Mu.Character.PathController.MoveEvent do
  use Kalevala.Character.Event

  alias Mu.Character.TeleportAction
  alias Mu.Character.NonPlayerController
  alias Mu.Character.Action

  defdelegate commit(conn, event), to: Mu.Character.MoveEvent

  # TODO: Log aborts during speedwalks
  # TODO: handle doors for intelligent characters
  def abort(conn, _event) do
    destination = get_flash(conn, :destination_id)

    conn
    |> Action.stop()
    |> TeleportAction.put(%{room_id: destination})
    |> put_controller(NonPlayerController)
  end
end

defmodule Mu.Character.PathEvents do
  use Kalevala.Event.Router

  @moduledoc """
  Ignore all events except moves
  """

  alias Kalevala.Event.Movement

  scope(Mu.Character) do
    module(PathController.MoveEvent) do
      event(Movement.Commit, :commit)
      event(Movement.Abort, :abort)
    end
  end
end

defmodule Mu.Character.PathController do
  @moduledoc """
  Controller for a non player to walk a path without interruption
  """
  defstruct [:path, :destination_id]

  use Kalevala.Character.Controller

  alias Mu.Character.SpeedWalkAction
  alias Mu.Character.EventAction
  alias Mu.Character.PathEvents
  alias Mu.Character.NonPlayerController

  @impl true
  def init(conn) do
    path = get_flash(conn, :path)
    walk_opts = [delay: 250, priority: 9]
    final_step_opts = [pre_delay: 250, priority: 9]

    conn
    |> SpeedWalkAction.put(%{directions: path}, walk_opts)
    |> EventAction.put(%{topic: "npc/path/end", data: %{}}, final_step_opts)
  end

  @impl true
  def recv(conn, _), do: conn

  @impl true
  def display(conn, _text), do: conn

  @impl true
  def event(conn, %{topic: "npc/path/end"}) do
    put_controller(conn, NonPlayerController)
  end

  def event(conn, event) do
    PathEvents.call(conn, event)
  end
end
