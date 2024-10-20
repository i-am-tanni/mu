defmodule Mu.Character.WhisperView do
  use Kalevala.Character.View

  alias Mu.Character.CharacterView

  def render("echo", %{character: character, text: text}) do
    [
      "You whisper to ",
      CharacterView.render("name", %{character: character}),
      ~i(, {color foreground="green"}"#{text}"{/color}\r\n)
    ]
  end

  def render("listen", %{whispering_character: character, text: text}) do
    [
      CharacterView.render("name", %{character: character}),
      ~i( whispers to you, {color foreground="green"}"#{text}"{/color}\r\n)
    ]
  end

  def render("obscured", %{whispering_character: whispering_character, character: character}) do
    [
      CharacterView.render("name", %{character: whispering_character}),
      " whispers to ",
      CharacterView.render("name", %{character: character}),
      ".\r\n"
    ]
  end

  def render("character-not-found", %{name: name}) do
    ~i(Character {color foreground="white"}#{name}{/color} could not be found.\r\n)
  end
end
