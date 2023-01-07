defmodule Mu.Character.PathFindView do
  use Kalevala.Character.View

  def render("unknown", %{text: text}) do
    ~i(You attempt to track "#{text}" but find nothing.\n)
  end

  def render("track/success", %{room_exit: nil}) do
    ~i(The quarry you are seeking is...in this very room!\n)
  end

  def render("track/success", %{room_exit: room_exit}) do
    ~i(You find signs that the quarry you are seeking is #{room_exit}.\n)
  end
end
