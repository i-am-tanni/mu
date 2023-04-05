defmodule Mu.Character.SpawnController do
  use Kalevala.Character.Controller

  alias Kalevala.Brain
  alias Mu.Character.MoveEvent
  alias Mu.Character.NonPlayerEvents
  alias Mu.Character.SpawnView
  alias Mu.Character.TellEvent
  alias Mu.CharacterChannel
  alias Mu.Communication

  @impl true
  def init(conn) do
    character = conn.character
    IO.inspect("starting character #{character.name}")

    conn =
      Enum.reduce(character.meta.initial_events, conn, fn initial_event, conn ->
        delay_event(conn, initial_event.delay, initial_event.topic, initial_event.data)
      end)

    conn
    |> add_vitals()
    |> move(:to, character.room_id, SpawnView, "spawn", %{})
    |> subscribe("rooms:#{character.room_id}", [], &MoveEvent.subscribe_error/2)
    |> register_and_subscribe_character_channel(character)
    |> event("room/look", %{})
  end

  def add_vitals(conn) do
    case is_nil(conn.character.meta.vitals) do
      true ->
        vitals = %Mu.Character.Vitals{
          health_points: 25,
          max_health_points: 25,
          skill_points: 0,
          max_skill_points: 0,
          endurance_points: 0,
          max_endurance_points: 0
        }

        put_meta(conn, :vitals, vitals)

      false ->
        conn
    end
  end

  @impl true
  def event(conn, event) do
    IO.inspect(event.topic, label: "event")

    # conn.character.brain
    # |> Brain.run(conn, event)
    NonPlayerEvents.call(conn, event)
  end

  @impl true
  def recv(conn, _text), do: conn

  @impl true
  def display(conn, _text), do: conn

  defp register_and_subscribe_character_channel(conn, character) do
    options = [character_id: character.id]
    :ok = Communication.register("characters:#{character.id}", CharacterChannel, options)

    options = [character: character]
    subscribe(conn, "characters:#{character.id}", options, &TellEvent.subscribe_error/2)
  end
end
