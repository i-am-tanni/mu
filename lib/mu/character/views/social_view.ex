defmodule Mu.Character.SocialView do
  use Kalevala.Character.View

  alias Mu.Character.CharacterView

  def render("char-no-arg", %{text: social}) do
    ~i(#{social.char_no_arg}\n)
  end

  def render("char-auto", %{text: social}) do
    ~i(#{social.char_auto}\n)
  end

  def render("others-no-arg", %{text: social, acting_character: acting_character}) do
    text = EEx.eval_string(social.others_no_arg, acting_character: acting_character)
    ~i(#{text})
  end

  def render("others-auto", %{text: social, acting_character: acting_character}) do
    text = EEx.eval_string(social.others_auto, acting_character: acting_character)
    ~i(#{text})
  end

  def render("char-found", %{
        text: social,
        acting_character: acting_character,
        character: character
      }) do
    text =
      EEx.eval_string(social.others_found,
        acting_character: acting_character,
        character: character
      )

    ~i(#{text})
  end

  def render("others-found", %{
        text: social,
        acting_character: acting_character,
        character: character
      }) do
    text =
      EEx.eval_string(social.char_found, acting_character: acting_character, character: character)

    ~i(#{text})
  end

  def render("victim-found", %{
        text: social,
        acting_character: acting_character,
        character: character
      }) do
    text =
      EEx.eval_string(social.vict_found, acting_character: acting_character, character: character)

    ~i(#{text})
  end

  def render("character-not-found", %{name: name}) do
    ~i(Character {color foreground="white"}#{name}{/color} could not be found.\n)
  end
end
