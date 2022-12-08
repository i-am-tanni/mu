defmodule Mu.Character.EmoteView do
  use Kalevala.Character.View

  alias Mu.Character.CharacterView

  def render("echo", %{character: character, text: text}) do
    ~i(#{CharacterView.render("name", %{character: character})} #{text}\n)
  end

  def render("list", %{emotes: emotes}) do
    available_emotes =
      emotes
      |> Enum.map(&render("_emote", %{emote: &1}))
      |> Enum.join("\n")

    ~E"""
    Emotes available:
    <%= available_emotes %>
    """
  end

  def render("_emote", %{emote: emote}) do
    ~i(- {color foreground="white"}#{emote}{/color})
  end

  def render("listen", %{character: character, text: text}) do
    ~i(#{CharacterView.render("name", %{character: character})} #{text}\n)
  end
end
