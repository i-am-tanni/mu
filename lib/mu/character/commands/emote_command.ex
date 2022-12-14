defmodule Mu.Character.EmoteCommand do
  use Kalevala.Character.Command

  alias Mu.Character.EmoteAction

  def broadcast(conn, params) do
    params = Map.put(params, "channel_name", "rooms:#{conn.character.room_id}")

    conn
    |> EmoteAction.run(params)
    |> assign(:prompt, false)
  end
end
