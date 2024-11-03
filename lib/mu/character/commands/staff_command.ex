defmodule Mu.Character.StaffCommand do
  use Kalevala.Character.Command

  alias Mu.Character.TeleportAction
  alias Mu.Character.Action
  alias Mu.Character.StaffView
  alias Mu.World.RoomIds

  @doc """
  Syntax: @teleport <zone_id> <room_id>

  Teleports to the destination.
  """
  def teleport(conn, params) do
    zone_id = params["zone_id"]
    room_id = params["room_id"]
    destination_id = "#{zone_id}.#{room_id}"

    case RoomIds.get(destination_id) do
      {:ok, room_id} ->
        conn
        |> Action.cancel()
        |> TeleportAction.run(%{room_id: room_id})

      :error ->
        conn
        |> assign(:prompt, true)
        |> assign(:room_id, destination_id)
        |> prompt(StaffView, "room-not-found")
    end

  end
end
