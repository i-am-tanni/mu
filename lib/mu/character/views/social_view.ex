defmodule Mu.Character.SocialView do
  use Kalevala.Character.View

  @moduledoc """
  Render for socials. There are three main types.
  - No arg
  - Auto (i.e. the acting character's argument is themself)
  - Vict (i.e. the acting character's argument has a target that was found)

  No Arg views:
  - "char_no_arg"
  - "others_no_arg"

  Auto views:
  - "char_auto"
  - "others_auto"

  Vict views:
  - "char_found"
  - "others_found"
  - "vict_found"
  """

  def render("char-no-arg", %{text: social, acting_character: acting_character}) do
    text = EEx.eval_string(social.char_no_arg, acting_character: acting_character)
    ~i(#{text}\n)
  end

  def render("char-auto", %{text: social, acting_character: acting_character}) do
    text = EEx.eval_string(social.char_auto, acting_character: acting_character)
    ~i(#{text}\n)
  end

  def render("others-no-arg", %{text: social, acting_character: acting_character}) do
    text = EEx.eval_string(social.others_no_arg, acting_character: acting_character)
    ~i(#{text}\n)
  end

  def render("others-auto", %{text: social, acting_character: acting_character}) do
    text = EEx.eval_string(social.others_auto, acting_character: acting_character)
    ~i(#{text}\n)
  end

  def render("char-found", %{
        text: social,
        acting_character: acting_character,
        at_character: at_character
      }) do
    text =
      EEx.eval_string(social.char_found,
        acting_character: acting_character,
        at_character: at_character
      )

    ~i(#{text}\n)
  end

  def render("others-found", %{
        text: social,
        acting_character: acting_character,
        at_character: at_character
      }) do
    text =
      EEx.eval_string(social.others_found,
        acting_character: acting_character,
        at_character: at_character
      )

    ~i(#{text}\n)
  end

  def render("vict-found", %{
        text: social,
        acting_character: acting_character,
        at_character: at_character
      }) do
    text =
      EEx.eval_string(social.vict_found,
        acting_character: acting_character,
        at_character: at_character
      )

    ~i(#{text}\n)
  end

  def render("character-not-found", %{name: name}) do
    ~i(Character {color foreground="white"}#{name}{/color} could not be found.\n)
  end
end
