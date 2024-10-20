defmodule Mu.Character.YellView do
  use Kalevala.Character.View

  alias Mu.Character.CharacterView

  def render("echo", %{text: text}) do
    ~i(You yell at the top of your lungs, '#{text}'\r\n)
  end

  def render("listen", %{text: text, rooms_away: 0, acting_character: character}) do
    [
      CharacterView.render("name", %{character: character}),
      ~i( yells, '#{text}'\r\n)
    ]
  end

  def render("listen", %{text: text, direction: direction, acting_character: character}) do
    [
      "From #{direction(direction)} you hear ",
      CharacterView.render("name", %{character: character}),
      ~i( yell, '#{text}'\r\n)
    ]
  end

  def direction(exit_name) do
    case exit_name do
      x when x in ["north", "south", "east", "west"] -> ~i(the #{exit_name})
      _ -> exit_name
    end
  end
end
