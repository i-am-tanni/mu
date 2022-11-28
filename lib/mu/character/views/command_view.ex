defmodule Mu.Character.CommandView do
  use Kalevala.Character.View

  def render("prompt", _assigns) do
    "<10h><2m> "
  end

  def render("unknown", _assigns) do
    "huh?\n"
  end
end
