defmodule Mu.Character.ReplyView do
  use Kalevala.Character.View

  def render("missing-reply-to", _assigns) do
    ~i(You need to receive a tell before you can reply!\r\n)
  end
end
