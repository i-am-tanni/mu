defmodule Mu.Character.ForwardEvent do
  use Kalevala.Character.Event

  def call(conn, event) do
    event(conn, event.topic, event.data)
  end
end
