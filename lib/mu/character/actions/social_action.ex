defmodule Mu.Character.SocialAction do
  @moduledoc """
  Action to use a social in a channel (e.g. a room)
  """

  use Kalevala.Character.Action

  @impl true
  def run(conn, params = %{"character" => nil}) do
    conn
    |> publish_message(
      params["channel_name"],
      params["social"],
      [type: "social", meta: meta(character: nil)],
      &publish_error/2
    )
    |> assign(:prompt, false)
  end

  def run(conn, params = %{"character" => "self"}) do
    params = %{params | "character" => conn.character.name}
    run(conn, params)
  end

  def run(conn, params) do
    params = %{
      name: params["character"],
      text: params["social"]
    }

    conn
    |> event("social/send", params)
  end

  defp meta(character: character) do
    %{
      at: character
    }
  end

  def publish_error(conn, _error), do: conn
end
