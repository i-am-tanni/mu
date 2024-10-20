defmodule Mu.Character.TellView do
  use Kalevala.Character.View

  alias Mu.Character.CharacterView

  def render("echo", %{character: character, text: text}) do
    [
      "You tell ",
      CharacterView.render("name", %{character: character}),
      ~i(, {color foreground="green"}"#{text}"{/color}\r\n)
    ]
  end

  def render("listen", %{character: character, text: text}) do
    [
      CharacterView.render("name", %{character: character}),
      ~i( tells you, {color foreground="green"}"#{text}"{/color}\r\n)
    ]
  end

  def render("character-not-found", %{name: name}) do
    ~i(Character {color foreground="white"}#{name}{/color} could not be found.\r\n)
  end
end
