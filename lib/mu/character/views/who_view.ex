defmodule Mu.Character.WhoView do
  use Kalevala.Character.View
  alias Mu.Character.CharacterView

  def render("list", %{characters: characters}) do
    lines = [
      render("_count", %{characters: characters}),
      render("_characters", %{characters: characters})
    ]

    lines
    |> Enum.reject(&is_nil/1)
    |> View.join("\n")
    |> newline()
  end

  def render("_count", %{characters: characters}) do
    count = Enum.count(characters)
    ~i(#{count} #{pluralize("character", count)} online)
  end

  def render("_characters", %{characters: []}), do: nil

  def render("_characters", %{characters: characters}) do
    characters
    |> Enum.map(&render("_character", %{character: &1}))
    |> View.join("\n")
  end

  def render("_character", %{character: character}) do
    ~i(  #{CharacterView.render("name", %{character: character})})
  end

  def newline(lines), do: [lines, "\n"]

  def pluralize(word, 1), do: word
  def pluralize(word, _), do: ~i(#{word}s)
end
