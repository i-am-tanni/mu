defmodule Mu.Character.CloseView do
  use Kalevala.Character.View
  alias Mu.Character.CharacterView

  def render("echo", %{direction: direction}) do
    ~i(You close the door #{direction}.\n)
  end

  def render("listen-origin", %{character: character, direction: direction}) do
    ~i(#{CharacterView.render("name", %{character: character})} closes the door #{direction}.\n)
  end

  def render("listen-destination", %{direction: direction}) do
    ~i(The door #{direction} closes.\n)
  end

  def render("not-found", %{keyword: keyword}) do
    ~i(Could not find any match to open: #{keyword}.\n)
  end

  def render("door-already-closed", %{direction: direction}) do
    ~i(The door #{direction} is already closed.)
  end
end
