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

  def run(conn, params = %{"character" => "self", "social" => social}) do
    cond do
      social.char_auto != nil and social.others_auto != nil ->
        params = %{params | "character" => conn.character.name}
        run(conn, params)

      true ->
        run(conn, %{params | "character" => nil})
    end
  end

  def run(conn, %{"character" => character, "social" => social})
      when social.vict_found != nil and social.others_found != nil do
    params = %{
      name: character,
      text: social
    }

    conn
    |> event("social/send", params)
  end

  def run(conn, params) do
    run(conn, %{params | "character" => nil})
  end

  defp meta(character: character) do
    %{
      at: character
    }
  end

  def publish_error(conn, _error), do: conn
end
