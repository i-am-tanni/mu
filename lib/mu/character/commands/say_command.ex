defmodule Mu.Character.SayCommand do
  use Kalevala.Character.Command

  alias Mu.Character.SayAction

  def run(conn, params = %{"at" => _}) do
    conn
    |> event("say/send", params)
    |> assign(:prompt, false)
  end

  def run(conn, params) do
    params = %SayAction{
      channel_name: "rooms:#{conn.character.room_id}",
      text: params["text"],
      adverb: params["adverb"]
    }

    conn
    |> SayAction.run(params)
    |> assign(:prompt, false)
  end
end
