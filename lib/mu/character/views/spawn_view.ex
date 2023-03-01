defmodule Mu.Character.SpawnView do
  use Kalevala.Character.View

  alias Mu.Character.CharacterView

  def render("spawn", %{character: character}) do
    ~i(#{CharacterView.render("name", %{character: character})} appears in a poof of smoke!)
  end
end
