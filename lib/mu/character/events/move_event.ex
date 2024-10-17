defmodule Mu.Character.MoveEvent do
  use Kalevala.Character.Event

  require Logger

  alias Mu.Character.Action
  alias Mu.Character.CommandView
  alias Mu.Character.MoveView

  # Movement TODO:
  # - Add a data parameter to request_movement(conn, exit_name, data)
  # Data can add context to the move -- i.e. is the character being forcefully moved?
  # I.e. what if a character is summoned, pushed, teleported, or banished?

  def commit(conn, %{data: event}) do
    conn
    |> move(:from, event.from, MoveView, "leave", %{to: event.exit_name})
    |> move(:to, event.to, MoveView, "enter", %{from: event.entrance_name})
    |> put_character(%{conn.character | room_id: event.to})
    |> unsubscribe("rooms:#{event.from}", [], &unsubscribe_error/2)
    |> subscribe("rooms:#{event.to}", [], &subscribe_error/2)
    |> event("room/look")
  end

  def abort(conn, %{data: event}) do
    conn =
      case get_meta(conn, :pose) do
        :pos_fleeing -> put_meta(conn, :pose, :pos_fighting)
        _ -> conn
      end

    conn
    |> Action.stop()
    |> render(MoveView, "fail", event)
    |> prompt(CommandView, "prompt")
  end

  def notice(conn, %{data: event}) do
    conn
    |> assign(:character, event.character)
    |> assign(:direction, event.direction)
    |> assign(:reason, event.reason)
    |> render(MoveView, "notice")
    |> prompt(CommandView, "prompt")
  end

  def unsubscribe_error(conn, error) do
    Logger.error("Tried to unsubscribe from the old room and failed - #{inspect(error)}")

    conn
  end

  def subscribe_error(conn, error) do
    Logger.error("Tried to subscribe to the new room and failed - #{inspect(error)}")

    conn
  end
end
