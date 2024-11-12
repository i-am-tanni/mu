defmodule Mu.Character.HuntController.MoveEvent do
  use Kalevala.Character.Event

  alias Mu.Character.WanderAction
  alias Mu.Character.MoveAction
  alias Mu.Character.LookAction
  alias Mu.Character.TeleportAction
  alias Mu.Character.CombatAction

  alias Mu.Character.NonPlayerController

  def commit(conn, %{data: event}) do
    # update path back to origin

    return_path = get_flash(conn, :return_path)
    return_path = [event.entrance_name | return_path]
    attempts = get_flash(conn, :attempts)

    conn =
      case attempts > 0 do
        true -> put_flash(conn, :attempts, 0)
        false -> conn
      end

    put_flash(conn, :return_path, return_path)
  end

  # This is most likely to happen due to a closed door
  # TODO: Have intelligent monsters open doors while hunting
  def abort(conn, _) do
    attempts = get_flash(conn, :attempts)

    # if a move fails in excess of 5 times in a single room
    case attempts > 5 do
      true ->
        room_id = get_flash(conn, :room_id)

        # abandon the hunt and teleport home
        conn
        |> put_flash(:attempts, 0)
        |> TeleportAction.put(%{room_id: room_id})
        |> put_controller(NonPlayerController)

      false ->
        # otherwise increment attempts and try again
        conn
        |> put_flash(:attempts, attempts + 1)
        |> WanderAction.put(%{})
        |> LookAction.put(%{at: :characters})
    end
  end

  def notice(conn, %{data: event}) do
    target_id = get_flash(conn, :target_id)

    # if movement notice relates to the character non-player is hunting...
    case target_id == event.character.id do
      true ->
        pre_delay = Enum.random(500..3000)

        case event.data do
          # attack
          %{from: _} ->
            attack_data = Mu.Character.build_attack(conn, target_id)
            CombatAction.put(conn, attack_data, pre_delay: pre_delay)

          # resume hunt
          %{to: nil} ->
            conn
            |> WanderAction.put(%{})
            |> LookAction.put(%{at: :characters})

          # or pursue
          %{to: exit_name} ->
            conn
            |> MoveAction.put(%{direction: exit_name}, pre_delay: pre_delay)
            |> LookAction.put(%{at: :characters})
        end

      false ->
        conn
    end
  end
end

defmodule Mu.Character.HuntEvents do
  @moduledoc """
  Special events that can:
    - result in a state transition
    - mutate the hunt data
  """

  use Kalevala.Event.Router

  alias Kalevala.Event.Movement

  scope(Mu.Character) do
    module(HuntController.MoveEvent) do
      event(Movement.Commit, :commit)
      event(Movement.Notice, :notice)
      event(Movement.Abort, :abort)
    end

    module(HuntEvent) do
      event("room/chars", :call)
    end
  end
end

defmodule Mu.Character.HuntController do
  @moduledoc """
  Controller for non-players to hunt other characters
  """

  defstruct [:target_id, :room_id, :expires_at, :initial_exit_name, :return_path, :attempts]

  use Kalevala.Character.Controller

  alias Mu.Character.NonPlayerEvents
  alias Mu.Character.HuntEvents
  alias Mu.Character.NonPlayerEvents

  alias Mu.Character.Action
  alias Mu.Character.MoveAction
  alias Mu.Character.LookAction

  @impl true
  def init(conn) do
    exit_name = get_flash(conn, :initial_exit_name)
    pre_delay = Enum.random(1500..4500)

    conn
    |> put_flash(:attempts, 0)
    |> Action.cancel()
    |> MoveAction.put(%{direction: exit_name}, pre_delay: pre_delay)
    |> LookAction.put(%{at: :characters})
  end

  @impl true
  def event(conn, event) do
    IO.inspect(event.topic, label: "event #{conn.character.id}")

    # conn.character.brain
    # |> Brain.run(conn, event)
    conn
    |> HuntEvents.call(event)
    |> NonPlayerEvents.call(event)
  end

  @impl true
  def recv(conn, _), do: conn

  @impl true
  def display(conn, _text), do: conn
end
