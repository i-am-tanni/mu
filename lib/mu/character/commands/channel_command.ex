defmodule Mu.Character.ChannelCommand do
  use Kalevala.Character.Command

  def ooc(conn, params) do
    conn
    |> publish_message("ooc", params["text"], [], &publish_error/2)
    |> assign(:prompt, false)
  end

  def publish_error(conn, _error), do: conn
end
