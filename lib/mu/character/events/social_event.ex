defmodule Mu.Character.SocialEvent do
  use Kalevala.Character.Event

  require Logger

  alias Mu.Character.CommandView
  alias Mu.Character.SocialView
  alias Mu.Character

  def interested?(event) do
    event.data.type == "social" && match?("rooms:" <> _, event.data.channel_name)
  end

  def broadcast(conn, %{data: %{character: character, text: social}}) when character != nil do
    options = [
      type: "social",
      meta: %{
        at: character
      }
    ]

    conn
    |> publish_message("rooms:#{conn.character.room_id}", social, options, &publish_error/2)
  end

  def broadcast(conn, event) do
    conn
    |> assign(:name, event.data.name)
    |> render(SocialView, "character-not-found")
    |> prompt(CommandView, "prompt", %{})
  end

  def echo(conn, event) do
    at_character = event.data.meta.at && Character.fill_pronouns(event.data.meta.at)

    conn
    |> assign(:acting_character, Character.fill_pronouns(event.acting_character))
    |> assign(:at_character, at_character)
    |> assign(:id, event.data.id)
    |> assign(:text, event.data.text)
    |> render(SocialView, social_view(conn, event))
    |> assign(:character, conn.character)
    |> prompt(CommandView, "prompt", %{})
  end

  defp social_view(conn, event) do
    cond do
      is_nil(event.data.meta.at) and conn.character.id == event.acting_character.id ->
        "char-no-arg"

      is_nil(event.data.meta.at) ->
        "others-no-arg"

      conn.character.id == event.acting_character.id and
          conn.character.id == event.data.meta.at.id ->
        "char-auto"

      conn.character.id == event.acting_character.id ->
        "char-found"

      conn.character.id == event.data.meta.at.id ->
        "vict-found"

      event.acting_character.id == event.data.meta.at.id ->
        "others-auto"

      true ->
        "others-found"
    end
  end

  def subscribe_error(conn, error) do
    Logger.error("Tried to subscribe to the new channel and failed - #{inspect(error)}")

    conn
  end

  def publish_error(conn, error) do
    Logger.error("Tried to publish to a channel and failed - #{inspect(error)}")

    conn
  end
end
