defmodule Mu.Character.CharacterView do
  use Kalevala.Character.View

  def render("name", %{character: character}) do
    ~i({character id="#{character.id}" name="#{character.name}" description="#{character.description}"}#{character.name}{/character})
  end

  def render("character-name", _assigns) do
    ~s(What is your name? )
  end
end
