defmodule Mu.Character.QuitView do
  use Kalevala.Character.View

  alias Mu.Character.CharacterView

  # passed to foreman disconnect
  def render("disconnected", %{character: character}) do
    [
      "Notify: ",
      CharacterView.render("name", %{character: character}),
      " leaves in a swirl of mist."
    ]
  end

  def render("goodbye", _assigns) do
    "Goodbye!\r\n"
  end
end
