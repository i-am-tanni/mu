defmodule Mu.Character.OpenView do
  use Kalevala.Character.View
  alias Mu.Character.CharacterView

  def render("echo", %{direction: direction}) do
    ~i(You open the door #{direction}.\r\n)
  end

  def render("listen-origin", %{character: character, direction: direction}) do
    ~i(#{CharacterView.render("name", %{character: character})} opens the door #{direction}.\r\n)
  end

  def render("listen-destination", %{direction: direction}) do
    ~i(The door #{direction} opens.\r\n)
  end

  def render("not-found", %{keyword: keyword}) do
    ~i(Could not find any match to open: #{keyword}.\r\n)
  end

  def render("door-locked", %{direction: direction}) do
    ~i(The door #{direction} is locked.\r\n)
  end

  def render("door-already-open", %{direction: direction}) do
    ~i(The door #{direction} is already open.\r\n)
  end
end
