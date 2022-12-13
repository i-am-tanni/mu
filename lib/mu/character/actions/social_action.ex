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
  end

  def meta(character: character) do
    %{
      at: character
    }
  end

  def publish_error(conn, _error), do: conn
end
