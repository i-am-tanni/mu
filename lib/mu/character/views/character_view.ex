defmodule Mu.Character.CharacterView do
  use Kalevala.Character.View

  def render("name", %{character: character}) do
    ~i({character id="#{character.id}" name="#{character.name}" description="#{character.description}"}#{character.name}{/character})
  end

  def render("name-possessive", %{character: character}) do
    possessive = possessive(character.name)

    ~i({character id="#{character.id}" name="#{character.name}" description="#{character.description}"}#{possessive}{/character})
  end

  def render("character-name", _assigns) do
    ~s(What is your name? )
  end

  def render("error", %{reason: reason}) do
    reason
  end

  defp possessive(subject) do
    case Regex.match?(~r/s$/, subject) do
      true -> [subject, "'"]
      false -> [subject, "'s"]
    end
  end
end
