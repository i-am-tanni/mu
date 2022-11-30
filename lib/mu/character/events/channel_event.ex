defmodule Mu.Character.ChannelEvent do
  use Kalevala.Character.Event

  alias Mu.Character.ChannelView
  alias Mu.Character.CommandView

  def interested?(event) do
    match?("ooc", event.data.channel_name)
  end

  def echo(conn, event) do
    conn
    |> assign(:channel_name, event.data.channel_name)
    |> assign(:character, event.data.character)
    |> assign(:id, event.data.id)
    |> assign(:text, event.data.text)
    |> render(ChannelView, "listen")
    |> prompt(CommandView, "prompt", %{})
  end

  def subscribe_error(conn, _error), do: conn
end
