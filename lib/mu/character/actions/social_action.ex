defmodule Mu.Character.SocialAction do
  @moduledoc """
  Action to use a social in a channel (e.g. a room)
  """

  use Mu.Character.Action

  @impl true

  def run(conn, params = %{"at_character" => nil, "social" => social}) do
    conn
    |> publish_message(
      params["channel_name"],
      social,
      [type: "social", meta: meta(character: nil)],
      &publish_error/2
    )
    |> assign(:prompt, false)
  end

  def run(conn, params = %{"at_character" => at_character, "social" => social}) do
    self? =
      matches?(String.downcase(at_character), "self") or
        Mu.Character.matches?(conn.character, at_character)

    cond do
      self? and has_auto_views?(social) ->
        send_event(conn, social, conn.character.name)

      !self? and has_vict_views?(social) ->
        send_event(conn, social, at_character)

      true ->
        run(conn, %{params | "at_character" => nil})
    end
  end

  @impl true
  def build(params, _opts \\ []) do
    %Action{
      type: __MODULE__,
      priority: 3,
      conditions: [:pos_sitting],
      steps: [
        Action.step(__MODULE__, 0, params)
      ]
    }
  end

  defp send_event(conn, social, at_character) do
    params = %{
      name: at_character,
      text: social
    }

    event(conn, "social/send", params)
  end

  defp matches?(string1, string2), do: String.downcase(string1) == String.downcase(string2)

  defp has_auto_views?(social), do: !!(social.char_auto && social.others_auto)

  defp has_vict_views?(social) do
    !!(social.vict_found && social.others_found && social.char_found)
  end

  defp meta(character: at_character) do
    %{
      at: at_character
    }
  end

  def publish_error(conn, _error), do: conn
end
