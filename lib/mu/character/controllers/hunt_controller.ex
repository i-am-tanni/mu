defmodule Mu.Character.HuntController.MoveEvent do
  use Kalevala.Character.Event

  alias Mu.Character.WanderAction
  alias Mu.Character.MoveAction
  alias Mu.Character.ListAction
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
        |> ListAction.put(%{type: :characters})
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
            |> ListAction.put(%{type: :characters})

          # or pursue
          %{to: exit_name} ->
            conn
            |> MoveAction.put(%{direction: exit_name}, pre_delay: pre_delay)
            |> ListAction.put(%{type: :characters})
        end

      false ->
        conn
    end
  end
end

defmodule Mu.Character.HuntEvent do
  use Kalevala.Character.Event
  import Mu.Character.Guards

  alias Mu.Character
  alias Mu.Character.PathController

  # Actions
  alias Mu.Character.WanderAction
  alias Mu.Character.ListAction
  alias Mu.Character.CombatAction

  def call(conn, event) when not in_combat(conn) do
    target_id = get_flash(conn, :target_id)
    expires_at = get_flash(conn, :expires_at)

    # As long as the hunt hasn't expired
    case Time.compare(Time.utc_now(), expires_at) == :lt do
      true ->
        # If quarry is in the room
        case Enum.find(event.data.characters, &Character.matches?(&1, target_id)) do
          # attack
          %{} ->
            attack_data = Character.build_attack(conn, target_id)
            CombatAction.put(conn, attack_data)

          # ...or continue hunting
          nil ->
            conn
            |> WanderAction.put(%{}, pre_delay: 3000)
            |> ListAction.put(%{type: :characters})
        end

      false ->
        # but if expired, path home
        threat_table = get_meta(conn, :threat_table)
        return_path = get_flash(conn, :return_path)
        destination = get_flash(conn, :room_id)

        data = %PathController{
          path: return_path,
          destination_id: destination
        }

        conn
        |> put_meta(:threat_table, refresh(threat_table))
        |> put_controller(PathController, data)
    end
  end

  def call(conn, _), do: conn

  defp refresh(threat_table) do
    threat_table
    |> Enum.filter(fn {_, %{expires_at: expires_at}} ->
      Time.compare(Time.utc_now(), expires_at) == :lt
    end)
    |> Enum.into(%{})
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
  alias Mu.Character.ListAction

  @impl true
  def init(conn) do
    IO.puts("Entered Hunting Controller")

    exit_name = get_flash(conn, :initial_exit_name)
    pre_delay = Enum.random(1500..4500)

    conn
    |> Action.stop()
    |> put_flash(:attempts, 0)
    |> MoveAction.put(%{direction: exit_name}, pre_delay: pre_delay)
    |> ListAction.put(%{type: :characters})
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
