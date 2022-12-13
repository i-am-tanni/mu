defmodule Mu.Character.SocialEvent do
  use Kalevala.Character.Event

  require Logger

  alias Mu.Character.CommandView
  alias Mu.Character.SocialView

  def interested?(event) do
    event.data.type == "social" && match?("rooms:" <> _, event.data.channel_name)
  end

  def broadcast(conn, %{data: %{character: character, social: social}}) when character != nil do
    options = [
      type: "social",
      meta: %{
        at: character
      }
    ]

    conn
    |> assign(:character, character)
    |> assign(:social, social)
    |> render(SocialView, "broadcast-with-target")
    |> publish_message("rooms:#{conn.character.room_id}", social, options, &publish_error/2)
  end

  def broadcast(conn, event) do
    conn
    |> assign(:name, event.data.name)
    |> render(SocialView, "character-not-found")
    |> prompt(CommandView, "prompt", %{})
  end

  def echo(conn, event) do
    conn
    |> assign(:acting_character, event.acting_character)
    |> assign(:character, event.data.meta.at)
    |> assign(:id, event.data.id)
    |> assign(:text, event.data.text)
    |> render(SocialView, social_view(conn, event))
    |> prompt(CommandView, "prompt", %{})
  end

  defp social_view(conn, event) do
    cond do
      event.data.meta.at == nil and conn.character.id == event.acting_character.id ->
        "char-no-arg"

      event.data.meta.at == nil ->
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
