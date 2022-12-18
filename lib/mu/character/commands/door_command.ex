defmodule Mu.Character.DoorCommand do
  use Kalevala.Character.Command

  def run(conn, params) do
    topic = topic(params)

    conn
    |> event(topic, %{text: params["text"]})
    |> assign(:prompt, false)
  end

  defp topic(%{"command" => command}) do
    case command do
      "open" -> "room/open"
      "close" -> "room/close"
    end
  end
end
