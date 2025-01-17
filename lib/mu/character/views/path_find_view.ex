defmodule Mu.Character.PathFindView do
  use Kalevala.Character.View

  def render("unknown", %{text: text}) do
    ~i(You attempt to track "#{text}" but find nothing.\r\n)
  end

  def render("track/success", %{exit_name: nil}) do
    ~i(The quarry you are seeking is...in this very room!\r\n)
  end

  def render("track/success", %{exit_name: exit_name}) do
    ~i(You find signs that the quarry you are seeking is #{exit_name}.\r\n)
  end
end
