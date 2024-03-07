defmodule Mu.Character.NonPlayerController do
  use Kalevala.Character.Controller

  alias Mu.Character.NonPlayerEvents
  alias Mu.Character.WanderAction
  alias Mu.Character.AiCombatController

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

  def event(conn, event = %{topic: "combat/kickoff"}) do
    self_id = conn.character.id
    victim_id = event.data.victim.id
    attacker_id = event.data.attacker.id

    case self_id do
      ^victim_id ->
        data = %AiCombatController{target: event.data.attacker, initial_event: event}
        put_controller(conn, AiCombatController, data)

      ^attacker_id ->
        data = %AiCombatController{target: event.data.victim, initial_event: event}
        put_controller(conn, AiCombatController, data)

      _ ->
        NonPlayerEvents.call(conn, event)
    end
  end

  def event(conn, event) do
    IO.inspect(event.topic, label: "event #{conn.character.id}")

    # conn.character.brain
    # |> Brain.run(conn, event)
    NonPlayerEvents.call(conn, event)
  end

  @impl true
  def recv(conn, _), do: conn

  @impl true
  def display(conn, _text), do: conn
end
