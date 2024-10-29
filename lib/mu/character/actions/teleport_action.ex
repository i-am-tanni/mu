defmodule Mu.Character.TeleportAction do
  require Logger
  use Mu.Character.Action

  alias Mu.Character.MoveView

  @impl true
  def run(conn, %{room_id: to}) do
    from = conn.character.room_id

    conn
    |> move(:from, from, MoveView, "teleport/leave", %{to: nil})
    |> move(:to, to, MoveView, "teleport/enter", %{from: nil})
    |> put_character(%{conn.character | room_id: to})
    |> unsubscribe("rooms:#{from}", [], &unsubscribe_error/2)
    |> subscribe("rooms:#{to}", [], &subscribe_error/2)
    |> event("room/look")
  end

  @impl true
  def build(params, _opts \\ []) do
    %Action{
      type: __MODULE__,
      priority: 8,
      conditions: [:pos_standing],
      steps: [
        Action.step(__MODULE__, 500, params)
      ]
    }
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
