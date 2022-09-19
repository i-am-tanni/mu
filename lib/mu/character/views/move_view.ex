defmodule Mu.Character.MoveView do
  use Kalevala.Character.View

  alias Mu.Character.CharacterView

  def render("enter", %{character: character}) do
    ~i(#{CharacterView.render("name", %{character: character})} enters.)
  end

  def render("leave", %{character: character}) do
    ~i(#{CharacterView.render("name", %{character: character})} leaves.)
  end
end
