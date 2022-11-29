defmodule Mu.Character.MoveView do
  use Kalevala.Character.View

  alias Mu.Character.CharacterView

  def render("enter", %{character: character}) do
    ~i(#{CharacterView.render("name", %{character: character})} enters.)
  end

  def render("leave", %{character: character}) do
    ~i(#{CharacterView.render("name", %{character: character})} leaves.)
  end

  def render("notice", %{direction: :to, reason: reason}) do
    [reason, "\n"]
  end

  def render("notice", %{direction: :from, reason: reason}) do
    [reason, "\n"]
  end

  def render("fail", %{reason: :no_exit, exit_name: exit_name}) do
    ~i(There is no exit #{exit_name}.\n)
  end
end
