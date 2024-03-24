defmodule Mu.Character.NonPlayerController do
  use Kalevala.Character.Controller

  alias Mu.Character.NonPlayerEvents
  alias Mu.Character.WanderAction

  @impl true
  def init(conn) do
    move_delay = get_meta(conn, :move_delay)

    case get_meta(conn, :flags) do
      %{sentinel?: false} -> delay_event(conn, move_delay, "npc/wander", %{})
      _ -> conn
    end
  end

  @impl true
  def event(conn, %{topic: "npc/wander"}) do
    move_delay = get_meta(conn, :move_delay)
    WanderAction.loop(conn, %{}, delay: move_delay)
  end

  def event(conn, event) do
    IO.inspect(event.topic, label: "event #{conn.character.id}")

    conn.character.brain
    |> Kalevala.Brain.run(conn, event)
    |> NonPlayerEvents.call(event)
  end

  @impl true
  def recv(conn, _), do: conn

  @impl true
  def display(conn, _text), do: conn
end
