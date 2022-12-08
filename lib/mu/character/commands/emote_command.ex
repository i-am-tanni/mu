defmodule Mu.Character.EmoteCommand do
  use Kalevala.Character.Command, dynamic: true

  alias Mu.Character.Emotes
  alias Mu.Character.EmoteAction
  alias Mu.Character.EmoteView

  def broadcast(conn, params) do
    params = Map.put(params, "channel_name", "rooms:#{conn.character.room_id}")

    conn
    |> EmoteAction.run(params)
    |> assign(:prompt, false)
  end
end
