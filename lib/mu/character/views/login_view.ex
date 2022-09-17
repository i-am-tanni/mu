defmodule Mu.Character.LoginView do
  use Kalevala.Character.View

  def render("echo", assigns) do
    assigns.data
  end

  def render("welcome", _assigns) do
    ~E"""
    Welcome to
    {color foreground="256:111"}
    __  ____   ____  __ _   _ ___
    |  \/  \ \ / /  \/  | | | |   \
    | |\/| |\ V /| |\/| | |_| | |) |
    |_|  |_| |_| |_|  |_|\___/|___/
    {/color}
    <%= render("powered-by", %{}) %>
    """
  end

  def render("powered-by", _assigns) do
    [
      ~s(Powered by {color foreground="256:39"}Kalevala{/color} 🧝 ),
      ~s({color foreground="cyan"}v#{Kalevala.version()}{/color}.)
    ]
  end

  def render("username", _assigns) do
    ~s(Username?  )
  end
end
