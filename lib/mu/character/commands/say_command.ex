defmodule Mu.Character.SayCommand do
  use Kalevala.Character.Command

  alias Mu.Character.SayAction

  def run(conn, params = %{"at" => _at}) do
    IO.inspect(params)

    conn
    |> event("say/send", params)
    |> assign(:prompt, false)
  end

  def run(conn, params) do
    IO.inspect(params)
    params = Map.put(params, "channel_name", "rooms:#{conn.character.room_id}")

    conn
    |> SayAction.run(params)
    |> assign(:prompt, false)
  end
end
